import SwiftUI
import SwiftData

@main
struct PostitApp: App {
    private let services = AppServices.shared
    #if os(macOS)
    @NSApplicationDelegateAdaptor(StickyAppDelegate.self) private var appDelegate
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage("collapsed") private var collapsed = false
    #endif

    var body: some Scene {
        #if os(macOS)
        // 포스트잇 창은 StickyAppDelegate가 AppKit으로 직접 만든다
        // (시스템 창 테두리와 강제 둥근 모서리 없이, 입력·크기 조절은 그대로 되도록).
        Settings {
            SettingsView()
                .environment(services.settings)
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Toggle("항상 위에 띄우기", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button(collapsed ? "펼치기" : "접기") { collapsed.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("지금 동기화") { services.cloud.syncNow(services.context) }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("포스트잇 보이기") { appDelegate.showSticky() }
                    .keyboardShortcut("0", modifiers: .command)
            }
            #if DEBUG
            CommandMenu("개발") {
                Button("더미 데이터 넣기 (일주일)") {
                    SampleData.insert(into: services.context)
                }
                Button("더미 데이터 지우기") {
                    SampleData.removeAll(from: services.context)
                }
            }
            #endif
        }
        #else
        WindowGroup {
            StickyView()
                .environment(services.settings)
                .environment(services.cloud)
                .modelContainer(services.modelContainer)
                #if DEBUG
                .task { services.handleDebugLaunchArguments() }
                #endif
        }
        #endif
    }
}
