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
            .background(settings.paper.color)
            .environment(\.colorScheme, .light)
            .onChange(of: filter) { limit = Theme.pageSize }
            // 자정이 지나면 어제 항목에 날짜 머리글이 붙도록 "오늘"을 갱신
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                today = Calendar.current.startOfDay(for: .now)
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
            TextField("한 줄 적고 ⏎", text: $draft)
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .foregroundStyle(Theme.ink)
                .focused($inputFocused)
                .onSubmit(add)
                .submitLabel(.done)
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.ink.opacity(inputFocused ? 0.25 : 0.1)).frame(height: 1)
        }
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

            if let message = cloud.message {
                Label(message, systemImage: cloud.symbol)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.author)
                    .help(message)
            }

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
