import SwiftUI
import SwiftData

/// 접힌 스티커: 설정한 이름과 남은 할 일 개수만 보여 주는 얇은 띠.
/// 이름은 iCloud 설정으로 동기화되므로 다른 기기에서 바꿔도 그대로 따라온다.
/// 더블클릭하면 펼쳐진다.
struct CollapsedStrip: View {
    let title: String
    @Query private var openItems: [NoteItem]
    @Environment(StickySettings.self) private var settings

    init(stickyID: UUID, title: String) {
        self.title = title
        let sid: UUID? = stickyID
        _openItems = Query(filter: #Predicate<NoteItem> { $0.stickyID == sid && $0.doneRank == 0 })
    }

    /// 포스트잇 이름이 있으면 이름, 없으면 설정한 작성자 이름
    private var label: String {
        if !title.isEmpty { return title }
        return settings.authorName.isEmpty ? "Postit" : settings.authorName
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(settings.font.font(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .lineLimit(1)

            Spacer(minLength: 8)

            if !openItems.isEmpty {
                Text("\(openItems.count)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.author)
                    .help("남은 할 일 \(openItems.count)개")
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .help("더블클릭하면 펼쳐집니다")
    }
}
