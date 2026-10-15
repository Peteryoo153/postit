import SwiftUI
import SwiftData

extension Notification.Name {
    /// 맥: 이 포스트잇을 새 창으로 연다 (object = UUID)
    static let postitOpenSticky = Notification.Name("postitOpenSticky")
    /// 맥: 새 포스트잇을 만들어 연다 (열린 창이 최대치면 안내만)
    static let postitNewSticky = Notification.Name("postitNewSticky")
    /// 맥: 이 포스트잇 창을 닫는다 (object = UUID)
    static let postitCloseSticky = Notification.Name("postitCloseSticky")
    /// 이 포스트잇의 입력칸에 커서를 둔다 (object = UUID) — 전역 단축키용
    static let postitFocusInput = Notification.Name("postitFocusInput")
}

/// 포스트잇 한 장. Figma 스티키 구성: 종이색 배경 · 넉넉한 여백 · 본문 · 하단 작성자.
struct StickyView: View {
    let stickyID: UUID
    /// iOS: 다른 포스트잇으로 넘길 때
    var onSelect: ((UUID) -> Void)? = nil

    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(CloudStatus.self) private var cloud
    @Query private var stickies: [Sticky]
    @Query(sort: \Sticky.createdAt) private var allStickies: [Sticky]

    @State private var draft = ""
    @State private var draftLabel: NoteLabel = .none
    @State private var limit = Theme.pageSize
    @State private var filter: NoteLabel?
    @State private var showSettings = false
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var today = Calendar.current.startOfDay(for: .now)
    @FocusState private var inputFocused: Bool
    #if os(macOS)
    @AppStorage private var collapsed: Bool
    #endif

    init(stickyID: UUID, onSelect: ((UUID) -> Void)? = nil) {
        self.stickyID = stickyID
        self.onSelect = onSelect
        _stickies = Query(filter: #Predicate<Sticky> { $0.id == stickyID })
        #if os(macOS)
        _collapsed = AppStorage(wrappedValue: false, OpenStickies.collapsedKey(stickyID))
        #endif
    }

    private var sticky: Sticky? { stickies.first }
    private var paper: PaperColor { sticky?.paper ?? settings.paper }

    var body: some View {
        paperBackground(content)
            .environment(\.colorScheme, .light)
            .onChange(of: filter) { limit = Theme.pageSize }
            // 자정이 지나면 어제 항목에 날짜 머리글이 붙도록 "오늘"을 갱신하고 못 끝낸 일을 Today로
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                today = Calendar.current.startOfDay(for: .now)
                AppServices.shared.refreshOnActivation()
            }
            .onReceive(NotificationCenter.default.publisher(for: Self.didBecomeActive)) { _ in
                today = Calendar.current.startOfDay(for: .now)
                AppServices.shared.refreshOnActivation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .postitFocusInput)) { note in
                guard note.object as? UUID == stickyID else { return }
                #if os(macOS)
                collapsed = false
                #endif
                inputFocused = true
            }
            .alert("포스트잇 이름", isPresented: $renaming) {
                TextField("예: 교회, 개인", text: $newTitle)
                Button("저장") { sticky?.title = newTitle.trimmingCharacters(in: .whitespaces) }
                Button("취소", role: .cancel) {}
            }
            .confirmationDialog(
                "이 포스트잇과 안의 할 일을 모두 지울까요?",
                isPresented: $confirmDelete, titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive, action: deleteSticky)
            } message: {
                Text("모든 기기에서 함께 지워집니다.")
            }
            #if os(iOS)
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            Button("완료") { showSettings = false }
                        }
                }
            }
            #endif
    }

    #if os(macOS)
    private static let didBecomeActive = NSApplication.didBecomeActiveNotification
    #else
    private static let didBecomeActive = UIApplication.didBecomeActiveNotification
    #endif

    /// 종이 배경. 맥은 설정한 둥글기로 자른 모양,
    /// iOS는 시계·홈 막대 영역까지 화면 끝까지 칠해서 종이 한 장이 화면 전체인 것처럼.
    @ViewBuilder
    private func paperBackground<V: View>(_ view: V) -> some View {
        #if os(macOS)
        let shape = RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
        view
            .background(paper.color, in: shape)
            .clipShape(shape)
        #else
        view
            .background { paper.color.ignoresSafeArea() }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        if collapsed {
            CollapsedStrip(stickyID: stickyID, title: sticky?.title ?? "")
                .onTapGesture(count: 2) { collapsed = false }
        } else {
            expanded
                // 위쪽 빈 곳을 더블클릭하면 접힌다 (맥 스티커처럼)
                .overlay(alignment: .top) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: Theme.topPadding - 12)
                        .onTapGesture(count: 2) { collapsed = true }
                }
        }
        #else
        expanded
        #endif
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: settings.rowSpacing + 6) {
                    VStack(alignment: .leading, spacing: 6) {
                        DayHeader(title: "Today")
                        inputRow
                    }
                    NoteList(stickyID: stickyID, today: today, limit: limit, filter: filter) {
                        limit += Theme.pageSize
                    }
                    .id(filter)
                }
                .padding(.horizontal, Theme.padding)
                .padding(.top, Theme.topPadding)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)

            footer
                .padding(.horizontal, Theme.padding)
                .padding(.bottom, Theme.bottomPadding)
                .padding(.top, 8)
        }
    }

    // MARK: 입력 줄 — 엔터마다 한 줄씩 추가, 새 항목은 맨 위로

    private var inputRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LineBox(font: settings.textFont) { LabelPill(label: $draftLabel) }
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .foregroundStyle(Theme.ink)
                .focused($inputFocused)
                .onSubmit(add)
                .submitLabel(.done)
                // 안내 문구: 얇은 "Todo" (입력하면 사라짐)
                .overlay(alignment: .leading) {
                    if draft.isEmpty {
                        Text("Todo")
                            .font(settings.font.font(size: settings.fontSize, weight: .light))
                            .foregroundStyle(Theme.ink.opacity(0.28))
                            .allowsHitTesting(false)
                    }
                }
        }
        // 아주 옅은 회색 박스로 입력칸임을 알 수 있게.
        // 박스 안쪽 여백만큼 바깥으로 넓혀서 블릿이 아래 목록과 같은 줄에 맞도록 한다.
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Theme.ink.opacity(inputFocused ? 0.06 : 0.04),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .padding(.horizontal, -10)
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(duration: 0.35)) {
            context.insert(NoteItem(text: text, label: draftLabel, stickyID: stickyID))
        }
        draft = ""
        inputFocused = true
        #if os(macOS)
        // 입력칸을 비운 기록은 버린다 → 바로 ⌘Z 하면 방금 추가한 항목이 취소된다
        DispatchQueue.main.async { (NSApp.keyWindow as? StickyWindow)?.textUndo.removeAllActions() }
        #endif
    }

    // MARK: 하단 — 작성자 · 동기화 상태 · 포스트잇 메뉴 · 설정

    private var footer: some View {
        HStack(spacing: 12) {
            // 날짜 머리글과 같은 글꼴·크기
            DayHeader(title: settings.authorName.isEmpty ? " " : settings.authorName)
                .lineLimit(1)

            Spacer()

            // 동기화 상태: 전 · 중(깜빡임) · 완료 — 누르면 지금 동기화
            Button {
                cloud.syncNow(context)
            } label: {
                Image(systemName: cloud.symbol)
                    .foregroundStyle(cloud.state == .error ? Theme.Label.red : Theme.author)
                    .symbolEffect(.pulse, isActive: cloud.state == .syncing)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help("\(cloud.message) — 누르면 지금 동기화")
            .accessibilityLabel(cloud.message)
            .accessibilityHint("지금 동기화")

            stickyMenu

            settingsButton
        }
        .font(.system(size: 14))
    }

    /// 이 포스트잇 메뉴: 라벨 필터 · 종이 색 · 이름 · 새 포스트잇/전환 · 삭제
    private var stickyMenu: some View {
        Menu {
            Picker("라벨 필터", selection: $filter) {
                Text("전체").tag(NoteLabel?.none)
                ForEach(NoteLabel.allCases.filter { $0 != .none }) { l in
                    Text(l.title).tag(Optional(l))
                }
            }

            Picker("종이 색", selection: Binding(
                get: { paper },
                set: { sticky?.paper = $0 }
            )) {
                ForEach(PaperColor.allCases) { Text($0.title).tag($0) }
            }

            Button("이름 바꾸기…") {
                newTitle = sticky?.title ?? ""
                renaming = true
            }

            Divider()

            #if os(macOS)
            Menu("포스트잇 열기") {
                ForEach(allStickies) { s in
                    Button(s.title.isEmpty ? "이름 없음 (\(s.paper.title))" : s.title) {
                        NotificationCenter.default.post(name: .postitOpenSticky, object: s.id)
                    }
                }
            }
            #else
            Picker("포스트잇 전환", selection: Binding(
                get: { stickyID },
                set: { onSelect?($0) }
            )) {
                ForEach(allStickies) { s in
                    Text(s.title.isEmpty ? "이름 없음" : s.title).tag(s.id)
                }
            }
            #endif
            Button("새 포스트잇") { openNewSticky() }

            if stickyID != StickyStore.defaultID {
                Button("이 포스트잇 삭제…", role: .destructive) { confirmDelete = true }
            }
        } label: {
            Image(systemName: filter == nil ? "ellipsis.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(filter?.color ?? Theme.author)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("이 포스트잇: 필터 · 색 · 이름 · 새 포스트잇")
    }

    private func openNewSticky() {
        #if os(macOS)
        NotificationCenter.default.post(name: .postitNewSticky, object: nil)
        #else
        onSelect?(StickyStore.create(in: context, paper: settings.paper).id)
        #endif
    }

    private func deleteSticky() {
        let id = stickyID
        #if os(macOS)
        NotificationCenter.default.post(name: .postitCloseSticky, object: id)
        #else
        onSelect?(StickyStore.defaultID)
        #endif
        StickyStore.delete(id, in: context)
    }

    @ViewBuilder
    private var settingsButton: some View {
        #if os(macOS)
        SettingsLink {
            Image(systemName: "gearshape").foregroundStyle(Theme.author)
        }
        .buttonStyle(.plain)
        #else
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape").foregroundStyle(Theme.author)
        }
        .buttonStyle(.plain)
        #endif
    }
}
