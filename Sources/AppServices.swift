import SwiftUI
import SwiftData
import CoreData
import UserNotifications

/// 앱 전체가 함께 쓰는 저장소·설정·동기화 상태.
/// 맥에서는 포스트잇 창을 AppKit으로 직접 만들기 때문에 SwiftUI App 밖에서도 접근할 수 있어야 한다.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let settings = StickySettings()
    let cloud = CloudStatus()
    let counter = TodayCounter()
    private let notificationDelegate = NotificationDelegate()

    let modelContainer: ModelContainer = {
        let schema = Schema([NoteItem.self, Sticky.self])
        // 저장소 파일을 반드시 Postit 전용 이름으로 둔다.
        // 기본값(default.store)은 샌드박스 밖에서 다른 SwiftData 앱과 같은 파일을 쓰게 된다.
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "Postit", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        let url = storeURL.appending(path: "Postit.store")

        // 애플 ID의 개인 iCloud DB로 동기화. 실행할 때마다 최신 변경을 자동으로 받아온다.
        // iCloud 권한 없이 서명된 빌드에서는 로컬 저장만 한다.
        let config = ModelConfiguration(
            "Postit",
            schema: schema,
            url: url,
            cloudKitDatabase: CloudEnvironment.isCloudKitEntitled
                ? .private(CloudEnvironment.containerID) : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("저장소를 열 수 없습니다: \(error)")
        }
    }()

    var context: ModelContext { modelContainer.mainContext }

    private init() {
        StickyStore.prepare(in: modelContainer.mainContext, defaultPaper: settings.paper)
        // ⌘Z 되돌리기 (체크·삭제·라벨 변경 등). 준비 작업 뒤에 켜서 되돌리기 목록에 안 남게.
        modelContainer.mainContext.undoManager = UndoManager()

        // 마감 알림: 저장할 때·다른 기기에서 받아왔을 때 다시 맞추고, 메뉴 막대 개수도 갱신
        UNUserNotificationCenter.current().delegate = notificationDelegate
        Reminders.registerCategories()
        let center = NotificationCenter.default
        for name in [ModelContext.didSave, NSPersistentCloudKitContainer.eventChangedNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    let services = AppServices.shared
                    Reminders.scheduleResync(services.context)
                    services.counter.refresh(services.context)
                }
            }
        }
        counter.refresh(context)
        Task { await Reminders.resync(context) }
    }

    /// 앱으로 돌아올 때마다: 동기화로 겹친 기본 포스트잇 정리 + 못 끝낸 일 Today로
    func refreshOnActivation() {
        let undo = context.undoManager
        context.undoManager = nil
        StickyStore.prepare(in: context, defaultPaper: settings.paper)
        DayRollover.run(in: context)
        context.undoManager = undo
        counter.refresh(context)
        Reminders.scheduleResync(context)
    }

    #if DEBUG || POSTIT_DEV
    /// 실행 인자로 더미 데이터를 넣고 뺄 수 있다: -seedSamples / -removeSamples
    func handleDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedSamples") { SampleData.insert(into: context) }
        if args.contains("-seedStickies") { SampleData.insertStickies(into: context) }
        if args.contains("-removeSamples") { SampleData.removeAll(from: context) }
        if args.contains("-resetLayout") {      // 새로 설치한 맥처럼 창 위치 기억을 지운다 (시험용)
            for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix("NSWindow Frame PostitSticky") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if args.contains("-removeExtraStickies") {
            for sticky in StickyStore.all(in: context) where sticky.id != StickyStore.defaultID {
                StickyStore.delete(sticky.id, in: context)
            }
        }
    }
    #endif
}

/// 오늘 남은 일 개수 (메뉴 막대 아이콘)
@MainActor
@Observable
final class TodayCounter {
    private(set) var remaining = 0
    private(set) var hasOverdue = false

    func refresh(_ context: ModelContext) {
        let open = (try? context.fetch(FetchDescriptor<NoteItem>(predicate: #Predicate { $0.isDone == false }))) ?? []
        remaining = open.count
        let now = Date.now
        hasOverdue = open.contains { ($0.dueDate ?? .distantFuture) < now }
    }
}

/// 알림이 앱을 쓰는 중에도 배너로 보이게 하고, [완료] [1시간 뒤]를 처리한다.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        guard let itemID = response.notification.request.content.userInfo["itemID"] as? String else { return }
        await MainActor.run {
            Reminders.handle(action: action, itemID: itemID, context: AppServices.shared.context)
        }
    }
}
