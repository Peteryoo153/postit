import SwiftUI
import SwiftData

/// 날짜별로 묶어서 보여준다. 최근 날짜가 위, 같은 날 안에서는 진행 중 → 완료.
/// 고정한(아직 안 끝낸) 항목은 위쪽 고정 구역에 따로 있으므로 여기서는 뺀다.
/// 검색 중에는 고정 여부와 상관없이 일치하는 모든 항목을 날짜별로 보여 준다.
/// 끝까지 스크롤하면 이전 항목을 더 불러온다.
struct NoteList: View {
    @Query private var items: [NoteItem]
    @Environment(StickySettings.self) private var settings
    @Environment(\.palette) private var palette
    let today: Date
    let limit: Int
    let query: String
    let loadMore: () -> Void

    init(stickyID: UUID, today: Date, limit: Int, filter: NoteLabel?, query: String,
         loadMore: @escaping () -> Void) {
        self.today = today
        self.limit = limit
        self.query = query
        self.loadMore = loadMore
        let sid: UUID? = stickyID
        let raw = filter?.rawValue ?? ""
        let useLabel = filter != nil
        let q = query.trimmingCharacters(in: .whitespaces)
        let useQuery = !q.isEmpty
        var descriptor = FetchDescriptor<NoteItem>(sortBy: NoteItem.listSort)
        descriptor.predicate = #Predicate {
            $0.stickyID == sid
                && (!useLabel || $0.labelRaw == raw)
                && ((useQuery && $0.text.localizedStandardContains(q))
                    || (!useQuery && ($0.isPinned == false || $0.isDone == true)))
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
            if items.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("“\(query)”에 맞는 할 일이 없어요")
                    .font(.system(size: settings.fontSize * 0.86))
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(Array(sections.enumerated()), id: \.element.day) { index, section in
                DayHeader(day: section.day, today: today)
                    .padding(.top, index == 0 ? 2 : 18)
                    .padding(.bottom, 2)
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
        .environment(\.searchQuery, query)
    }
}

/// 고정 구역: 아직 안 끝낸 고정 항목. 아래에 점선 한 줄로 구분한다.
struct PinnedList: View {
    @Query private var items: [NoteItem]
    @Environment(StickySettings.self) private var settings
    @Environment(\.palette) private var palette

    init(stickyID: UUID, filter: NoteLabel?) {
        let sid: UUID? = stickyID
        let raw = filter?.rawValue ?? ""
        let useLabel = filter != nil
        _items = Query(
            filter: #Predicate<NoteItem> {
                $0.stickyID == sid && $0.isPinned == true && $0.isDone == false
                    && (!useLabel || $0.labelRaw == raw)
            },
            sort: [SortDescriptor(\NoteItem.createdAt, order: .reverse)],
            animation: .default
        )
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: settings.rowSpacing) {
                ForEach(items) { item in
                    NoteRow(item: item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Line()
                    .stroke(palette.ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
            .padding(.bottom, 12)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

/// 날짜 머리글: "Today" = 본문 × 1.07 굵게 · 지난 날짜 "2026.10.16(Fri)" = × 0.86 보조색
struct DayHeader: View {
    let day: Date
    let today: Date
    @Environment(StickySettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        if day == today {
            Text("Today")
                .font(.system(size: settings.fontSize * 1.07, weight: .bold))
                .foregroundStyle(palette.ink)
        } else {
            Text(Self.format(day))
                .font(.system(size: settings.fontSize * 0.86, weight: .medium))
                .foregroundStyle(palette.secondary)
        }
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
