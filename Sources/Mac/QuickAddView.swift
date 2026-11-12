import SwiftUI
import SwiftData

/// 메뉴 막대 아이콘: 오늘 남은 일 개수 (마감 지난 일이 있으면 점)
struct MenuBarLabel: View {
    @Bindable var counter: TodayCounter

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "note.text")
            if counter.remaining > 0 {
                Text(counter.hasOverdue ? "\(counter.remaining)!" : "\(counter.remaining)").monospacedDigit()
            }
        }
        .accessibilityLabel("Postit 남은 일 \(counter.remaining)개")
    }
}

/// 메뉴 막대 빠른 입력: 팝오버 자체가 작은 포스트잇.
/// 열자마자 커서가 입력칸에 있고, 넣을 포스트잇은 칩으로 고른다(마지막 선택 기억).
struct QuickAddView: View {
    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Sticky.createdAt) private var stickies: [Sticky]
    @Query(filter: #Predicate<NoteItem> { $0.isDone == false }) private var openItems: [NoteItem]
    @AppStorage("quickAddSticky") private var selectedRaw = StickyStore.defaultID.uuidString
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var selected: Sticky? {
        let id = UUID(uuidString: selectedRaw)
        return stickies.first { $0.id == id } ?? stickies.first
    }
    private var palette: Palette {
        Palette(paperColor: selected?.paper ?? settings.paper, isDark: colorScheme == .dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            input
                .padding(14)

            chips
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            Rectangle().fill(palette.hairline).frame(height: 1)

            if let selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: settings.rowSpacing) {
                        QuickList(stickyID: selected.id)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(height: 220)
                .id(selected.id)
            }

            Rectangle().fill(palette.hairline).frame(height: 1)

            HStack {
                Text("오늘 남은 일 **\(openItems.count)** · 포스트잇 \(stickies.count)장")
                Spacer()
                Button("모두 보기 ⌘0") {
                    (NSApp.delegate as? StickyAppDelegate)?.showStickies()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("0")
            }
            .font(.system(size: 12))
            .foregroundStyle(palette.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 330)
        .background { PaperSurface(texture: settings.paperTexture) }
        .environment(\.palette, palette)
        .tint(palette.caret)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private var input: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondary)
            TextField("", text: $draft, prompt: Text("할 일 적기").foregroundStyle(palette.secondary))
                .textFieldStyle(.plain)
                .font(settings.font.font(size: 15, weight: settings.weight.weight))
                .foregroundStyle(palette.ink)
                .focused($focused)
                .onSubmit(add)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Array(stickies.prefix(StickyStore.maxOpen).enumerated()), id: \.element.id) { index, s in
                    let on = s.id == selected?.id
                    Button {
                        selectedRaw = s.id.uuidString
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(s.paper.color(dark: false)).frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(palette.ink.opacity(0.25), lineWidth: 0.5))
                            Text(s.title.isEmpty ? s.paper.title : s.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundStyle(on ? palette.paper : palette.ink)
                        .background(on ? palette.ink.opacity(0.85) : palette.ink.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Text("⌘1–\(min(stickies.count, StickyStore.maxOpen))")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary)
            }
        }
        .scrollIndicators(.never)
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let sticky = selected else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            context.insert(NoteItem(text: text, stickyID: sticky.id))
        }
        draft = ""
        focused = true
    }
}

/// 빠른 입력 아래 목록: 고정 + 남은 일
private struct QuickList: View {
    @Query private var items: [NoteItem]

    init(stickyID: UUID) {
        let sid: UUID? = stickyID
        var d = FetchDescriptor<NoteItem>(
            predicate: #Predicate { $0.stickyID == sid && $0.isDone == false },
            sortBy: [SortDescriptor(\.sortDate, order: .reverse)]
        )
        d.fetchLimit = 30
        _items = Query(d, animation: .default)
    }

    var body: some View {
        let pinned = items.filter(\.isPinned)
        let rest = items.filter { !$0.isPinned }
        ForEach(pinned) { NoteRow(item: $0) }
        ForEach(rest) { NoteRow(item: $0) }
        if items.isEmpty {
            Text("남은 일이 없어요")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        }
    }
}
