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
    /// 이 포스트잇에서 검색을 연다 (object = UUID) — ⌘F
    static let postitSearch = Notification.Name("postitSearch")
}

/// 포스트잇이 놓이는 자리
enum StickyLayout {
    /// 맥: 창 = 종이
    case window
    /// 아이폰(·좁은 아이패드): 화면 끝까지 칠한 한 장
    case page
    /// 아이패드 보드의 한 장
    case card
}

/// 포스트잇 한 장: 입력칸 → 고정 구역 → Today → 지난 날짜 → 아래 이름 줄.
struct StickyView: View {
    let stickyID: UUID
    var layout: StickyLayout = .window
    /// 보드 위 검색어 (있으면 이 장의 검색칸 대신 쓴다)
    var externalQuery: String? = nil
    /// 아이폰: 화면 끝까지 칠한 종이 안에서 글자가 피해야 할 시계·홈 막대 자리
    var safeInsets = EdgeInsets()
    /// iOS: 아래 이름 줄 가운데 점 (몇 번째 장인지)
    var pageIndex: Int? = nil
    var pageCount: Int = 0
    /// iOS: 다른 포스트잇으로 넘길 때
    var onSelect: ((UUID) -> Void)? = nil
    /// 아이패드 보드: 이 장을 크게 보기
    var onZoom: (() -> Void)? = nil

    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(CloudStatus.self) private var cloud
    @Environment(\.colorScheme) private var colorScheme
    @Query private var stickies: [Sticky]
    @Query(sort: \Sticky.createdAt) private var allStickies: [Sticky]

    @State private var draft = ""
    @State private var draftLabel: NoteLabel = .none
    @State private var limit = Theme.pageSize
    @State private var filter: NoteLabel?
    @State private var searching = false
    @State private var localQuery = ""
    @State private var showSettings = false
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var today = Calendar.current.startOfDay(for: .now)
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    #if os(macOS)
    @AppStorage private var collapsed: Bool
    #endif

    init(stickyID: UUID, layout: StickyLayout = .window, externalQuery: String? = nil,
         safeInsets: EdgeInsets = EdgeInsets(), pageIndex: Int? = nil, pageCount: Int = 0,
         onSelect: ((UUID) -> Void)? = nil, onZoom: (() -> Void)? = nil) {
        self.stickyID = stickyID
        self.layout = layout
        self.externalQuery = externalQuery
        self.safeInsets = safeInsets
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.onSelect = onSelect
        self.onZoom = onZoom
        _stickies = Query(filter: #Predicate<Sticky> { $0.id == stickyID })
        #if os(macOS)
        _collapsed = AppStorage(wrappedValue: false, OpenStickies.collapsedKey(stickyID))
        #endif
    }

    private var sticky: Sticky? { stickies.first }
    private var paper: PaperColor { sticky?.paper ?? settings.paper }
    private var palette: Palette { Palette(paperColor: paper, isDark: colorScheme == .dark) }
    private var query: String { externalQuery ?? (searching ? localQuery : "") }

    /// 이름 줄에 보이는 이름: 포스트잇 이름 → 작성자 이름 → Postit
    private var displayName: String {
        if let t = sticky?.title, !t.isEmpty { return t }
        return settings.authorName.isEmpty ? "Postit" : settings.authorName
    }

    var body: some View {
        paperBackground(content)
            .environment(\.palette, palette)
            .tint(palette.caret)
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
                searching = false
                inputFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .postitSearch)) { note in
                guard note.object as? UUID == stickyID else { return }
                #if os(macOS)
                collapsed = false
                #endif
                openSearch()
            }
            .alert("포스트잇 이름", isPresented: $renaming) {
                TextField("예: 교회, 학교", text: $newTitle)
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

    /// 종이 배경. 맥·보드는 설정한 둥글기로 자른 모양,
    /// 아이폰은 시계·홈 막대 영역까지 화면 끝까지 칠해서 종이 한 장이 화면 전체인 것처럼.
    @ViewBuilder
    private func paperBackground<V: View>(_ view: V) -> some View {
        let surface = PaperSurface(texture: settings.paperTexture).environment(\.palette, palette)
        switch layout {
        case .window, .card:
            let shape = RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
            view
                .background { surface }
                .clipShape(shape)
        case .page:
            view
                .background { surface.ignoresSafeArea() }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        if collapsed {
            CollapsedStrip(stickyID: stickyID, title: displayName, paper: paper)
                .onTapGesture(count: 2) { collapsed = false }
                .contextMenu { stickyMenuItems }
        } else {
            expanded
                // 위쪽 빈 곳: 더블클릭하면 접힌다 (맥 스티커처럼) · 우클릭하면 포스트잇 메뉴
                .overlay(alignment: .top) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: Theme.topPadding - 14)
                        .onTapGesture(count: 2) { collapsed = true }
                        .contextMenu { stickyMenuItems }
                }
        }
        #else
        expanded
        #endif
    }

    private var horizontalPadding: CGFloat { layout == .card ? 22 : Theme.padding }
    private var topPadding: CGFloat {
        switch layout {
        case .window: Theme.topPadding
        case .page: 12
        case .card: 20
        }
    }

    private var bottomPadding: CGFloat {
        switch layout {
        case .window: Theme.bottomPadding
        case .page: 12
        case .card: 16
        }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if externalQuery == nil {
                        Group {
                            if searching { searchRow } else { inputRow }
                        }
                        Rectangle().fill(palette.hairline).frame(height: 1)
                            .padding(.top, 8)
                            .padding(.bottom, 14)
                    }
                    if query.isEmpty {
                        PinnedList(stickyID: stickyID, filter: filter)
                    }
                    NoteList(stickyID: stickyID, today: today, limit: limit, filter: filter, query: query) {
                        limit += Theme.pageSize
                    }
                    .id("\(filter?.rawValue ?? "all")|\(query)")
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
            .scrollDismissesKeyboard(.interactively)

            footer
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
                .padding(.top, 8)
        }
    }

    // MARK: 입력 줄 — Return마다 한 줄씩 맨 위에 추가

    private var inputRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LineBox(font: settings.textFont) { LabelPill(label: $draftLabel, placeholderPlus: true) }
            TextField("", text: $draft, prompt: Text("할 일 적기").foregroundStyle(palette.secondary))
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .foregroundStyle(palette.ink)
                .focused($inputFocused)
                .onSubmit(add)
                .submitLabel(.done)
        }
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true }
    }

    private var searchRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LineBox(font: settings.textFont) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }
            TextField("", text: $localQuery, prompt: Text("모든 날짜에서 찾기").foregroundStyle(palette.secondary))
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .foregroundStyle(palette.ink)
                .focused($searchFocused)
                .submitLabel(.search)
                .onExitCommandIfAvailable { closeSearch() }
            Button(action: closeSearch) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(palette.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("검색 닫기")
        }
    }

    private func openSearch() {
        withAnimation(.snappy(duration: 0.2)) { searching = true }
        DispatchQueue.main.async { searchFocused = true }
    }

    private func closeSearch() {
        withAnimation(.snappy(duration: 0.2)) {
            searching = false
            localQuery = ""
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            context.insert(NoteItem(text: text, label: draftLabel, stickyID: stickyID))
        }
        draft = ""
        inputFocused = true
        #if os(macOS)
        // 입력칸을 비운 기록은 버린다 → 바로 ⌘Z 하면 방금 추가한 항목이 취소된다
        DispatchQueue.main.async { (NSApp.keyWindow as? StickyWindow)?.textUndo.removeAllActions() }
        #endif
    }

    // MARK: 아래 이름 줄 — 이름 · (페이지 점) · 동기화 상태 · 메뉴

    private var footer: some View {
        ZStack {
            if let pageIndex, pageCount > 1 {
                PageDots(index: pageIndex, count: pageCount)
            }
            HStack(spacing: 12) {
                Text(displayName)
                    .font(.system(size: max(11, settings.fontSize * 0.78), weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .onTapGesture { onZoom?() }

                Spacer()

                // 동기화 상태: 전 · 중(깜빡임) · 완료 — 누르면 지금 동기화
                Button {
                    cloud.syncNow(context)
                } label: {
                    Image(systemName: cloud.symbol)
                        .foregroundStyle(cloud.state == .error ? palette.overdue : palette.secondary)
                        .symbolEffect(.pulse, isActive: cloud.state == .syncing)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help("\(cloud.message) — 누르면 지금 동기화")
                .accessibilityLabel(cloud.message)
                .accessibilityHint("지금 동기화")

                Menu {
                    stickyMenuItems
                } label: {
                    Image(systemName: filter == nil ? "ellipsis.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(filter.map { palette.label($0) } ?? palette.secondary)
                        #if os(iOS)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        #endif
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("이 포스트잇: 검색 · 필터 · 색 · 이름 · 새 포스트잇")
            }
        }
        .font(.system(size: 14))
    }

    /// 이 포스트잇 메뉴 (아래 ··· · 맥은 위쪽 우클릭에서도)
    @ViewBuilder
    private var stickyMenuItems: some View {
        if let onZoom {
            Button("크게 보기", systemImage: "arrow.up.left.and.arrow.down.right", action: onZoom)
        }
        if externalQuery == nil {
            Button("검색", systemImage: "magnifyingglass", action: openSearch)
        }

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
        if layout == .page {
            Picker("포스트잇 전환", selection: Binding(
                get: { stickyID },
                set: { onSelect?($0) }
            )) {
                ForEach(allStickies) { s in
                    Text(s.title.isEmpty ? "이름 없음" : s.title).tag(s.id)
                }
            }
        }
        #endif
        Button("새 포스트잇") { openNewSticky() }
            .disabled(allStickies.count >= StickyStore.maxOpen && layout != .window)

        if stickyID != StickyStore.defaultID {
            Button("이 포스트잇 삭제…", role: .destructive) { confirmDelete = true }
        }

        Divider()
        #if os(macOS)
        SettingsLink { Text("설정…") }
        #else
        Button("설정", systemImage: "gearshape") { showSettings = true }
        #endif
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
}

/// 몇 번째 장인지: 점 n개 중 지금 장만 길게
struct PageDots: View {
    let index: Int
    let count: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(palette.ink.opacity(i == index ? 0.55 : 0.2))
                    .frame(width: i == index ? 14 : 5, height: 5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: index)
        .accessibilityElement()
        .accessibilityLabel("포스트잇 \(count)장 중 \(index + 1)번째")
    }
}

extension View {
    /// 맥: esc로 닫기
    @ViewBuilder
    func onExitCommandIfAvailable(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.onExitCommand(perform: action)
        #else
        self
        #endif
    }
}
