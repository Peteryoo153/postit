import SwiftUI
import SwiftData

/// 날짜별로 묶어서 보여준다. 최근 날짜가 위, 같은 날 안에서는 진행 중 → 완료.
/// 오늘 항목의 "Today" 표시는 입력 줄 위에 있으므로 여기서는 다른 날짜만 머리글을 단다.
/// 끝까지 스크롤하면 이전 항목을 더 불러온다.
struct NoteList: View {
    @Query private var items: [NoteItem]
    @Environment(StickySettings.self) private var settings
    let today: Date
    let limit: Int
    let loadMore: () -> Void

    init(today: Date, limit: Int, filter: NoteLabel?, loadMore: @escaping () -> Void) {
        self.today = today
        self.limit = limit
        self.loadMore = loadMore
        var descriptor = FetchDescriptor<NoteItem>(sortBy: NoteItem.listSort)
        if let raw = filter?.rawValue {
            descriptor.predicate = #Predicate { $0.labelRaw == raw }
        }
        descriptor.fetchLimit = limit
        _items = Query(descriptor, animation: .default)
    }

    private var sections: [(day: Date, items: [NoteItem])] {
        var result: [(day: Date, items: [NoteItem])] = []
        for item in items {
            if let last = result.indices.last, result[last].day == item.day {
                result[last].items.append(item)
            } else {
                result.append((item.day, [item]))
            }
        }
        return result
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: settings.rowSpacing) {
            ForEach(sections, id: \.day) { section in
                if section.day != today {
                    DayHeader(title: DayHeader.format(section.day))
                        .padding(.top, 18)
                }
                ForEach(section.items) { item in
                    NoteRow(item: item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if items.count >= limit {
                // 더보기: 이 행이 화면에 들어오면 이전 항목을 더 불러온다
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 8)
                .onAppear(perform: loadMore)
            }
        }
    }
}

/// 아주 작은 날짜 머리글: "Today" 또는 "2026.10.17(Sat)"
struct DayHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(Theme.author)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd(EEE)"
        return f
    }()

    static func format(_ day: Date) -> String {
        formatter.string(from: day)
    }
}
