import SwiftUI
import SwiftData

/// 진행 중(최신순) → 완료(최근 완료순). 끝까지 스크롤하면 다음 페이지를 불러온다.
struct NoteList: View {
    @Query private var items: [NoteItem]
    @Environment(StickySettings.self) private var settings
    let limit: Int
    let loadMore: () -> Void

    init(limit: Int, filter: NoteLabel?, loadMore: @escaping () -> Void) {
        self.limit = limit
        self.loadMore = loadMore
        var descriptor = FetchDescriptor<NoteItem>(sortBy: NoteItem.listSort)
        if let raw = filter?.rawValue {
            descriptor.predicate = #Predicate { $0.labelRaw == raw }
        }
        descriptor.fetchLimit = limit
        _items = Query(descriptor, animation: .default)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: settings.rowSpacing) {
            ForEach(items) { item in
                NoteRow(item: item)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
