import SwiftUI
import SwiftData

/// 접힌 스티커: 아직 안 끝난 맨 위 항목 한 줄과 남은 개수만 보여 주는 얇은 띠.
/// 더블클릭하면 펼쳐진다.
struct CollapsedStrip: View {
    @Query(filter: #Predicate<NoteItem> { $0.doneRank == 0 }, sort: NoteItem.listSort)
    private var openItems: [NoteItem]
    @Environment(StickySettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            if let first = openItems.first {
                RoundedRectangle(cornerRadius: 2)
                    .fill(first.label == .none ? Theme.ink.opacity(0.12) : first.label.color)
                    .frame(width: 4, height: 12)
                Text(first.text)
                    .font(settings.font.font(size: 13, weight: settings.weight.weight))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                DayHeader(title: "Today")
            }

            Spacer(minLength: 8)

            if openItems.count > 1 {
                Text("+\(openItems.count - 1)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.author)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .help("더블클릭하면 펼쳐집니다")
    }
}
