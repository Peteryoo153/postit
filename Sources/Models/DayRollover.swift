import Foundation
import SwiftData

/// 날이 바뀌면 지난 날 못 끝낸 일을 Today로 옮긴다.
/// 완료한 일은 완료한 날짜에 그대로 남는다.
/// 여러 기기에서 동시에 실행돼도 같은 값(오늘 날짜)을 쓰므로 충돌하지 않는다.
@MainActor
enum DayRollover {
    static func run(in context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<NoteItem>(
            predicate: #Predicate { $0.doneRank == 0 && $0.isDone == false && $0.day < today }
        )
        guard let carried = try? context.fetch(descriptor), !carried.isEmpty else { return }
        for item in carried {
            item.day = today
        }
        try? context.save()
    }
}
