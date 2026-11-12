import SwiftUI
import SwiftData

/// 접힌 띠: 이름 + 남은 개수 배지 + ⌄. 마감 지난 일이 있으면 배지 테두리가 빨강.
/// 맥에서는 접힌 창, 아이패드 "크게 보기"에서는 옆에 쌓인 다른 포스트잇으로 쓴다.
struct CollapsedStrip: View {
    let title: String
    let paper: PaperColor
    @Query private var openItems: [NoteItem]
    @Environment(StickySettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    init(stickyID: UUID, title: String, paper: PaperColor) {
        self.title = title
        self.paper = paper
        let sid: UUID? = stickyID
        _openItems = Query(filter: #Predicate<NoteItem> { $0.stickyID == sid && $0.isDone == false })
    }

    private var palette: Palette { Palette(paperColor: paper, isDark: colorScheme == .dark) }
    private var hasOverdue: Bool {
        let now = Date.now
        return openItems.contains { ($0.dueDate ?? .distantFuture) < now }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink.opacity(0.85))
                .lineLimit(1)

            if !openItems.isEmpty {
                Text("\(openItems.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.ink.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(palette.ink.opacity(0.10), in: Capsule())
                    .overlay {
                        if hasOverdue { Capsule().strokeBorder(palette.overdue, lineWidth: 1) }
                    }
                    .help(hasOverdue ? "남은 할 일 \(openItems.count)개 · 마감 지남 있음" : "남은 할 일 \(openItems.count)개")
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.secondary)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PaperSurface(texture: settings.paperTexture).environment(\.palette, palette) }
        .environment(\.palette, palette)
        .contentShape(Rectangle())
        .help("더블클릭하면 펼쳐집니다")
    }
}
