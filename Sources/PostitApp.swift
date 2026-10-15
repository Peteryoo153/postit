import SwiftUI
import SwiftData

@main
struct PostitApp: App {
    @State private var settings = StickySettings()
    @State private var cloud = CloudStatus()
    #if os(macOS)
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage("collapsed") private var collapsed = false
    #endif

    let modelContainer: ModelContainer = {
        let schema = Schema([NoteItem.self])
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

    var body: some Scene {
        #if os(macOS)
        Window("Postit", id: "sticky") {
            content
                .frame(minWidth: 260, idealWidth: 400,
                       minHeight: collapsed ? 1 : 300,  // 접힌 높이는 WindowChrome이 정한다 (제목줄 높이가 더해지지 않게)
                       idealHeight: 560)
                .ignoresSafeArea()
                .background(WindowChrome(collapsed: collapsed))
        }
        .windowStyle(.hiddenTitleBar)
        .windowLevel(alwaysOnTop ? .floating : .normal)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 400, height: 560)
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Toggle("항상 위에 띄우기", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button(collapsed ? "펼치기" : "접기") { collapsed.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            #if DEBUG
            CommandMenu("개발") {
                Button("더미 데이터 넣기 (일주일)") {
                    SampleData.insert(into: modelContainer.mainContext)
                }
                Button("더미 데이터 지우기") {
                    SampleData.removeAll(from: modelContainer.mainContext)
                }
            }
            #endif
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
        #else
        WindowGroup {
            content
                .modelContainer(modelContainer)
        }
        #endif
    }

    private var content: some View {
        StickyView()
            .environment(settings)
            .environment(cloud)
            #if DEBUG
            .task { handleDebugLaunchArguments() }
            #endif
    }

    #if DEBUG
    /// 실행 인자로 더미 데이터를 넣고 뺄 수 있다: -seedSamples / -removeSamples
    @MainActor
    private func handleDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedSamples") { SampleData.insert(into: modelContainer.mainContext) }
        if args.contains("-removeSamples") { SampleData.removeAll(from: modelContainer.mainContext) }
    }
    #endif
}
