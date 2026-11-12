import Foundation
import SwiftData
import UserNotifications

/// 마감 표시: 오늘 = 시각, 내일 = "내일 …", 이번 주 = 요일, 그 뒤 = 날짜. 지났으면 "· 지남".
enum DueState { case today, future, overdue }

struct DueInfo {
    let text: String
    let state: DueState

    init(_ due: Date, now: Date = .now) {
        let cal = Calendar.current
        let time = Self.time(due)
        if due < now {
            state = .overdue
            if cal.isDateInToday(due) { text = "\(time) · 지남" }
            else if cal.isDateInYesterday(due) { text = "어제 · 지남" }
            else { text = "\(Self.short(due)) · 지남" }
            return
        }
        if cal.isDateInToday(due) {
            state = .today
            text = time
            return
        }
        state = .future
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        if days == 1 { text = "내일 \(time)" }
        else if days < 7 { text = "\(Self.weekday(due)) \(time)" }
        else { text = Self.short(due) }
    }

    /// "오후 3시", "오전 9:30"
    static func time(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0
        let ampm = h < 12 ? "오전" : "오후"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(ampm) \(h12)시" : "\(ampm) \(h12):\(String(format: "%02d", m))"
    }

    static func weekday(_ date: Date) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return names[(Calendar.current.component(.weekday, from: date) - 1) % 7]
    }

    /// "10.15"
    static func short(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0).\(String(format: "%02d", c.day ?? 0))"
    }
}

/// 마감 빠른 선택: 오늘 저녁 · 내일 아침 · 주일 · 다음 주 월
enum DueQuickPick: CaseIterable, Identifiable {
    case tonight, tomorrowMorning, sunday, nextMonday
    var id: Self { self }

    var title: String {
        switch self {
        case .tonight: "오늘 저녁"
        case .tomorrowMorning: "내일 아침"
        case .sunday: "주일"
        case .nextMonday: "다음 주 월"
        }
    }

    func date(from now: Date = .now) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func at(_ day: Date, _ hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        switch self {
        case .tonight:
            return at(today, 18)
        case .tomorrowMorning:
            return at(cal.date(byAdding: .day, value: 1, to: today)!, 9)
        case .sunday:
            let next = cal.nextDate(after: today, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime)!
            return at(next, 9)
        case .nextMonday:
            let next = cal.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)!
            return at(next, 9)
        }
    }

    /// 버튼 오른쪽 작은 글자: "18:00" 또는 "10.18"
    func detail(from now: Date = .now) -> String {
        let d = date(from: now)
        switch self {
        case .tonight, .tomorrowMorning:
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        case .sunday, .nextMonday:
            return DueInfo.short(d)
        }
    }
}

/// 알림 시점 선택지 (분)
enum RemindOption: Int, CaseIterable, Identifiable {
    case none = -1, atTime = 0, min10 = 10, min30 = 30, hour1 = 60, day1 = 1440
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .none: "없음"
        case .atTime: "정시"
        case .min10: "10분 전"
        case .min30: "30분 전"
        case .hour1: "1시간 전"
        case .day1: "하루 전"
        }
    }
}

/// 마감 알림. 다른 기기에서 바꾼 마감도 반영되도록, 앱이 켜질 때·저장할 때 대기 중 알림을 통째로 다시 맞춘다.
@MainActor
enum Reminders {
    static let category = "postit.due"
    static let actionDone = "postit.done"
    static let actionSnooze = "postit.snooze"

    static func registerCategories() {
        let done = UNNotificationAction(identifier: actionDone, title: "완료")
        let snooze = UNNotificationAction(identifier: actionSnooze, title: "1시간 뒤")
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [done, snooze], intentIdentifiers: [])
        ])
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private static var rescheduleTask: Task<Void, Never>?

    /// 잠깐 모아서 한 번에 다시 맞춘다 (저장이 연달아 일어날 때)
    static func scheduleResync(_ context: ModelContext) {
        rescheduleTask?.cancel()
        rescheduleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await resync(context)
        }
    }

    static func resync(_ context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let now = Date.now
        let items = (try? context.fetch(FetchDescriptor<NoteItem>(
            predicate: #Predicate { $0.isDone == false && $0.dueDate != nil && $0.remindMinutes >= 0 }
        ))) ?? []
        let stickies = Dictionary(StickyStore.all(in: context).map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })

        var wanted: [String: UNNotificationRequest] = [:]
        for item in items {
            guard let due = item.dueDate else { continue }
            let fire = due.addingTimeInterval(-Double(item.remindMinutes) * 60)
            guard fire > now else { continue }
            let content = UNMutableNotificationContent()
            let name = item.stickyID.flatMap { stickies[$0] } ?? ""
            content.title = name.isEmpty ? "Postit" : name
            content.body = item.text
            content.subtitle = item.remindMinutes > 0
                ? "\(DueInfo.time(due)) 마감 · \(RemindOption(rawValue: item.remindMinutes)?.title ?? "")"
                : "\(DueInfo.time(due)) 마감"
            content.sound = .default
            content.categoryIdentifier = category
            content.userInfo = ["itemID": item.id.uuidString]
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "due.\(item.id.uuidString)"
            wanted[id] = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }

        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("due.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for request in wanted.values { try? await center.add(request) }
    }

    /// 알림의 [완료] [1시간 뒤]
    static func handle(action: String, itemID: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: itemID),
              let item = try? context.fetch(FetchDescriptor<NoteItem>(predicate: #Predicate { $0.id == uuid })).first
        else { return }
        switch action {
        case actionDone:
            item.setDone(true)
            item.settlePosition()
        case actionSnooze:
            item.dueDate = Date.now.addingTimeInterval(3600)
            item.remindMinutes = 0
        default:
            return
        }
        try? context.save()
    }
}
