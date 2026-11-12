#if DEBUG || POSTIT_DEV
import Foundation
import SwiftData

/// 테스트용 더미 데이터 (디버그 빌드 전용).
/// iCloud로 다른 기기에도 동기화되므로, 확인 후 "더미 데이터 지우기"로 한 번에 지운다.
@MainActor
enum SampleData {
    /// (며칠 전, 시:분, 텍스트, 라벨, 완료 여부)
    private static let entries: [(Int, Int, Int, String, NoteLabel, Bool)] = [
        (0, 8, 40, "주보 원고 최종 확인", .orange, false),
        (0, 10, 15, "대전 교회 회신 메일 발송", .blue, false),
        (0, 13, 30, "이번주 설교 준비 — 본문 묵상 정리", .purple, false),
        (0, 15, 5, "청년부 수련회 장소 견적 비교", .green, true),

        (1, 9, 0, "새가족 환영 문자 보내기", .green, true),
        (1, 11, 20, "교사 기도회 기도제목 취합", .purple, false),
        (1, 14, 0, "음향 장비 수리 업체 연락", .red, true),
        (1, 16, 45, "구역장 모임 자료 인쇄", .none, false),
        (1, 20, 10, "느헤미야 4장 주석 읽기", .purple, true),

        (2, 7, 50, "새벽기도 말씀 요약 올리기", .purple, true),
        (2, 10, 30, "재정부 영수증 정리", .orange, false),
        (2, 13, 0, "심방 일정: 김 집사님 댁 (오후 3시)", .red, true),

        (3, 9, 15, "학부모 교목실편지 초안", .blue, true),
        (3, 11, 40, "유튜브 썸네일 시안 확인", .yellow, false),
        (3, 15, 20, "성경공방 다음 영상 대본 개요", .yellow, true),
        (3, 17, 0, "주일 찬양 콘티 받기", .none, true),

        (4, 8, 30, "중보기도 명단 업데이트", .purple, true),
        (4, 12, 0, "교회 홈페이지 공지 수정", .blue, true),
        (4, 18, 30, "아이들 학교 상담 일정 확인", .green, false),

        (5, 10, 0, "선교사님 후원 보고서 발송", .blue, true),
        (5, 14, 30, "다음 달 행사 캘린더 정리", .orange, true),
        (5, 16, 0, "프린터 토너 주문", .none, true),
        (5, 21, 0, "개인 묵상: 시편 23편", .purple, true),

        (6, 9, 30, "당회 회의록 정리", .orange, true),
        (6, 11, 0, "새 학기 성경공부 교재 주문", .green, true),
        (6, 15, 45, "도보여행 특별설교 아이디어 메모", .purple, false),
    ]

    static func insert(into context: ModelContext) {
        // 이미 넣었으면 중복으로 넣지 않는다
        let existing = FetchDescriptor<NoteItem>(predicate: #Predicate { $0.isSample })
        if (try? context.fetchCount(existing)) ?? 0 > 0 { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for (daysAgo, hour, minute, text, label, done) in entries {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let created = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }

            let item = NoteItem(text: text, label: label, stickyID: StickyStore.defaultID)
            item.createdAt = created
            item.day = day
            item.isSample = true
            if done {
                item.isDone = true
                item.completedAt = min(created.addingTimeInterval(60 * 90), .now)
            }
            item.settlePosition()
            context.insert(item)
            // 고정 · 마감 예시
            if daysAgo == 0 && text.hasPrefix("이번주 설교") { item.isPinned = true }
            if daysAgo == 0 && text.hasPrefix("주보") {
                item.dueDate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: today)
            }
            if daysAgo == 0 && text.hasPrefix("대전") {
                item.dueDate = calendar.date(byAdding: .hour, value: -20, to: .now)
            }
            if daysAgo == 1 && text.hasPrefix("교사 기도회") {
                item.dueDate = calendar.date(byAdding: .day, value: 2, to: today)?.addingTimeInterval(17 * 3600)
            }
        }
        try? context.save()
    }

    /// 보드 확인용 포스트잇 몇 장 (교회 · 학교 · 집 · 성경공방)
    static func insertStickies(into context: ModelContext) {
        guard StickyStore.all(in: context).count < 2 else { return }
        StickyStore.all(in: context).first?.title = "교회"
        let extra: [(String, PaperColor, [String])] = [
            ("학교", .blue, ["10학년 성경 워크시트 인쇄", "학부모 상담 일정 회신", "H11 수행평가 채점"]),
            ("집", .green, ["아이 피아노 픽업", "세탁소 찾기", "장보기 — 우유, 사과, 계란"]),
            ("성경공방", .pink, ["느헤미야 강해 쇼츠 2편 편집", "썸네일 문구 3안"]),
        ]
        for (title, paper, texts) in extra {
            let s = Sticky(title: title, paper: paper)
            context.insert(s)
            for t in texts.reversed() {
                let item = NoteItem(text: t, stickyID: s.id)
                item.isSample = true
                context.insert(item)
            }
        }
        try? context.save()
    }

    static func removeAll(from context: ModelContext) {
        try? context.delete(model: NoteItem.self, where: #Predicate { $0.isSample })
        try? context.save()
    }

    // MARK: 앱스토어 스크린샷용 데모 (-seedMarketing)
    // 시뮬레이터와 시험용 Postit Dev에서만: 이 기기의 할 일·포스트잇을 모두 지우고 데모 내용으로 채운다.

    /// (텍스트, 라벨, 고정, 완료, 마감: (며칠 뒤, 시, 분)?)
    private typealias Row = (String, NoteLabel, Bool, Bool, (Int, Int, Int)?)

    static func insertMarketing(into context: ModelContext) {
        #if targetEnvironment(simulator) || POSTIT_DEV
        try? context.delete(model: NoteItem.self)
        for sticky in StickyStore.all(in: context) where sticky.id != StickyStore.defaultID {
            context.delete(sticky)
        }
        try? context.save()

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let base = Date.now.addingTimeInterval(-3600 * 24 * 30)
        let papers: [(String, PaperColor, [Row])] = [
            ("교회", .yellow, [
                ("느헤미야 4장 본문 관찰 정리", .purple, true, false, nil),
                ("주보 원고 — 광고 3건 확인", .orange, false, false, (0, 15, 0)),
                ("김 집사님 병원 심방", .red, false, false, (0, 19, 0)),
                ("금요 기도회 찬양 순서 보내기", .blue, false, false, nil),
                ("수련회 장소 견적 비교", .none, false, false, (-1, 17, 0)),
                ("헌금 봉투 주문", .green, false, true, nil),
            ]),
            ("학교", .blue, [
                ("10학년 성경 워크시트 인쇄", .purple, false, false, nil),
                ("학부모 상담 일정 회신", .none, false, false, (1, 10, 0)),
                ("H11 수행평가 채점", .red, false, false, (3, 17, 0)),
                ("채플 순서지 검토", .green, false, false, nil),
                ("교사 기도회 기도제목 정리", .none, false, true, nil),
            ]),
            ("성경공방", .pink, [
                ("느헤미야 강해 쇼츠 2편 편집", .red, true, false, nil),
                ("썸네일 문구 3안", .yellow, false, false, nil),
                ("설명란 타임스탬프", .blue, false, false, (0, 22, 0)),
                ("댓글 답글 달기", .none, false, true, nil),
            ]),
            ("집", .green, [
                ("아이 피아노 픽업", .orange, false, false, (0, 16, 30)),
                ("세탁소 찾기", .none, false, false, nil),
                ("장보기 — 우유, 사과, 계란", .none, false, false, nil),
                ("보험 서류 제출", .none, false, false, (-3, 18, 0)),
            ]),
            ("설교 메모", .violet, [
                ("“무너진 성벽” 예화 — 지역 기사 스크랩", .purple, false, false, nil),
                ("바른 시리즈 7편 제목 후보", .none, false, false, nil),
                ("도보여행 특별설교 본문: 시편 121편", .green, false, false, nil),
            ]),
            ("이번 주", .orange, [
                ("교목실편지 12호 초안", .blue, false, false, (5, 12, 0)),
                ("수련회 공지 올리기", .none, false, false, nil),
                ("차량 점검 예약", .none, false, true, nil),
            ]),
        ]

        for (index, (title, paper, rows)) in papers.enumerated() {
            let sticky: Sticky
            if index == 0, let first = StickyStore.all(in: context).first(where: { $0.id == StickyStore.defaultID }) {
                sticky = first
                sticky.title = title
                sticky.paper = paper
                sticky.isOpen = true
                sticky.createdAt = base.addingTimeInterval(-60)
            } else {
                sticky = Sticky(title: title, paper: paper)
                sticky.createdAt = base.addingTimeInterval(Double(index) * 60)
                context.insert(sticky)
            }
            // 아래 줄부터 넣어야 위에서부터 순서대로 보인다 (최신이 위)
            for (offset, row) in rows.enumerated().reversed() {
                let (text, label, pinned, done, due) = row
                let item = NoteItem(text: text, label: label, stickyID: sticky.id)
                let created = cal.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
                    .addingTimeInterval(Double(rows.count - offset) * 600)
                item.createdAt = created
                item.isPinned = pinned
                if let (days, h, m) = due,
                   let day = cal.date(byAdding: .day, value: days, to: today) {
                    item.dueDate = cal.date(bySettingHour: h, minute: m, second: 0, of: day)
                    item.remindMinutes = 10
                }
                if done {
                    item.isDone = true
                    item.completedAt = created.addingTimeInterval(1800)
                }
                item.settlePosition()
                context.insert(item)
            }
            // 어제 끝낸 일 두어 개 (날짜 머리글이 보이도록)
            if index < 2 {
                let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
                for (t, l) in index == 0 ? [("주보 인쇄소 연락", NoteLabel.orange), ("새가족 환영 문자", .green)]
                                         : [("M8 출석부 제출", NoteLabel.none)] {
                    let item = NoteItem(text: t, label: l, stickyID: sticky.id)
                    item.createdAt = yesterday.addingTimeInterval(3600 * 10)
                    item.day = yesterday
                    item.isDone = true
                    item.completedAt = yesterday.addingTimeInterval(3600 * 15)
                    item.settlePosition()
                    context.insert(item)
                }
            }
        }
        try? context.save()
        #endif
    }
}
#endif
