import SwiftUI
import SwiftData

@main
struct PostitApp: App {
    static let cloudContainerID = "iCloud.com.peter.postit"

    @State private var settings = StickySettings()
    @State private var cloud = CloudStatus(containerID: PostitApp.cloudContainerID)
    #if os(macOS)
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    #endif

    let modelContainer: ModelContainer = {
        let schema = Schema([NoteItem.self])
        // 애플 ID의 개인 iCloud DB로 동기화. 실행할 때마다 최신 변경을 자동으로 받아온다.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(PostitApp.cloudContainerID)
        )
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }
        // iCloud 설정이 안 된 빌드(서명 전 등)에서는 로컬 저장으로 동작
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: localConfig)
    }()

    var body: some Scene {
        #if os(macOS)
        Window("Postit", id: "sticky") {
            content
                .frame(minWidth: 260, idealWidth: 400, minHeight: 300, idealHeight: 560)
                .ignoresSafeArea()
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
            }
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
    }
}
