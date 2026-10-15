import Foundation
import SwiftData

/// 포스트잇의 한 줄.
/// CloudKit 동기화 규칙: 모든 속성은 기본값이 있거나 옵셔널, @Attribute(.unique) 금지.
@Model
final class NoteItem {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date.now
    var completedAt: Date?
    var isDone: Bool = false
    var labelRaw: String = NoteLabel.none.rawValue

    /// 정렬용 키. 0 = 진행 중(위), 1 = 완료(아래).
    /// Bool은 SortDescriptor에서 쓸 수 없어서 Int로 따로 둔다.
    var doneRank: Int = 0
    /// 진행 중이면 작성 시각, 완료면 완료 시각. 최신이 위로.
    var sortDate: Date = Date.now
    /// 작성한 날(자정 기준). 날짜별 구분과 정렬에 쓴다.
    var day: Date = Calendar.current.startOfDay(for: .now)

    init(text: String, label: NoteLabel = .none) {
        let now = Date.now
        self.text = text
        self.createdAt = now
        self.sortDate = now
        self.day = Calendar.current.startOfDay(for: now)
        self.labelRaw = label.rawValue
    }

    var label: NoteLabel {
        get { NoteLabel(rawValue: labelRaw) ?? .none }
        set { labelRaw = newValue.rawValue }
    }

    /// 체크 표시만 먼저 바꾼다 (밑줄/흐림이 즉시 보이도록).
    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? .now : nil
    }

    /// 체크 상태에 맞게 리스트 위치를 옮긴다 (약간의 지연 후 호출).
    func settlePosition() {
        doneRank = isDone ? 1 : 0
        sortDate = isDone ? (completedAt ?? .now) : createdAt
    }

    /// 최근 날짜가 위로. 같은 날 안에서는 진행 중(최신순) → 완료(최근 완료순).
    static var listSort: [SortDescriptor<NoteItem>] {
        [SortDescriptor(\.day, order: .reverse),
         SortDescriptor(\.doneRank),
         SortDescriptor(\.sortDate, order: .reverse)]
    }
}
