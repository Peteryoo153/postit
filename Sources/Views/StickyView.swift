import SwiftUI
import SwiftData

/// 포스트잇 한 장. Figma 스티키 구성: 종이색 배경 · 넉넉한 여백 · 본문 · 하단 작성자.
struct StickyView: View {
    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(CloudStatus.self) private var cloud

    @State private var draft = ""
    @State private var draftLabel: NoteLabel = .none
    @State private var limit = Theme.pageSize
    @State private var filter: NoteLabel?
    @State private var showSettings = false
    @State private var today = Calendar.current.startOfDay(for: .now)
    @FocusState private var inputFocused: Bool
    #if os(macOS)
    @AppStorage("collapsed") private var collapsed = false
    #endif

    var body: some View {
        content
            .background(settings.paper.color, in: paperShape)
            .clipShape(paperShape)
            .environment(\.colorScheme, .light)
            .onChange(of: filter) { limit = Theme.pageSize }
            // 자정이 지나면 어제 항목에 날짜 머리글이 붙도록 "오늘"을 갱신
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                today = Calendar.current.startOfDay(for: .now)
                DayRollover.run(in: context)
            }
            // 못 끝낸 일을 Today로: 실행할 때, 자정이 지날 때, 앱으로 돌아올 때
            .task { DayRollover.run(in: context) }
            .onReceive(NotificationCenter.default.publisher(for: Self.didBecomeActive)) { _ in
                today = Calendar.current.startOfDay(for: .now)
                DayRollover.run(in: context)
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

    /// 포스트잇 외곽 모양. 맥에서는 설정한 둥글기, iOS는 화면을 꽉 채우므로 사각.
    private var paperShape: RoundedRectangle {
        #if os(macOS)
        RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
        #else
        RoundedRectangle(cornerRadius: 0)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        if collapsed {
            CollapsedStrip()
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
                    NoteList(today: today, limit: limit, filter: filter) {
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
            context.insert(NoteItem(text: text, label: draftLabel))
        }
        draft = ""
        inputFocused = true
    }

    // MARK: 하단 — 작성자 · 동기화 상태 · 필터 · 설정

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

            Menu {
                Picker("라벨 필터", selection: $filter) {
                    Text("전체").tag(NoteLabel?.none)
                    ForEach(NoteLabel.allCases.filter { $0 != .none }) { l in
                        Text(l.title).tag(Optional(l))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: filter == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(filter?.color ?? Theme.author)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()

            settingsButton
        }
        .font(.system(size: 14))
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
