import SwiftUI
import SwiftData

/// 앱 전체가 함께 쓰는 저장소·설정·동기화 상태.
/// 맥에서는 포스트잇 창을 AppKit으로 직접 만들기 때문에 SwiftUI App 밖에서도 접근할 수 있어야 한다.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let settings = StickySettings()
    let cloud = CloudStatus()

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
    }

    /// 앱으로 돌아올 때마다: 동기화로 겹친 기본 포스트잇 정리 + 못 끝낸 일 Today로
    func refreshOnActivation() {
        let undo = context.undoManager
        context.undoManager = nil
        StickyStore.prepare(in: context, defaultPaper: settings.paper)
        DayRollover.run(in: context)
        context.undoManager = undo
    }

    #if DEBUG
    /// 실행 인자로 더미 데이터를 넣고 뺄 수 있다: -seedSamples / -removeSamples
    func handleDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedSamples") { SampleData.insert(into: context) }
        if args.contains("-removeSamples") { SampleData.removeAll(from: context) }
        if args.contains("-removeExtraStickies") {
            for sticky in StickyStore.all(in: context) where sticky.id != StickyStore.defaultID {
                StickyStore.delete(sticky.id, in: context)
            }
        }
    }
    #endif
}
