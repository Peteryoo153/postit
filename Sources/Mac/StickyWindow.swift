import SwiftUI
import AppKit

/// 테두리 없는 포스트잇 창.
/// 기본 NSWindow는 테두리가 없으면 키보드 입력을 받지 못하고 ⌘W·⌘M도 동작하지 않아서 직접 허용한다.
final class StickyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: 종이 아무 곳이나 끌어서 창 이동
    // SwiftUI 내용 영역이 마우스를 먼저 받아서 isMovableByWindowBackground가 동작하지 않으므로,
    // 눌렀다가 조금 끌면 창이 직접 이동을 시작한다. 클릭(체크박스·버튼)은 그대로 전달된다.

    private var dragStart: NSPoint?
    private static let dragThreshold: CGFloat = 4
    private static let resizeEdge: CGFloat = 8

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragStart = canStartMove(at: event.locationInWindow) ? event.locationInWindow : nil
        case .leftMouseDragged:
            if let start = dragStart {
                let p = event.locationInWindow
                if hypot(p.x - start.x, p.y - start.y) >= Self.dragThreshold {
                    dragStart = nil
                    performDrag(with: event)
                    return
                }
            }
        case .leftMouseUp:
            dragStart = nil
        default:
            break
        }
        super.sendEvent(event)
    }

    /// 입력칸(글자 선택)이나 가장자리(크기 조절)에서는 이동하지 않는다.
    private func canStartMove(at point: NSPoint) -> Bool {
        let size = frame.size
        if point.x < Self.resizeEdge || point.x > size.width - Self.resizeEdge
            || point.y < Self.resizeEdge || point.y > size.height - Self.resizeEdge {
            return false
        }
        // hitTest는 받는 뷰의 '부모' 좌표계를 쓴다 (호스팅 뷰는 위아래가 뒤집혀 있어서 주의)
        guard let content = contentView,
              let parent = content.superview,
              var view = content.hitTest(parent.convert(point, from: nil)) else { return true }
        while true {
            if view is NSText || view is NSTextField { return false }
            guard let parent = view.superview else { return true }
            view = parent
        }
    }

    override func performClose(_ sender: Any?) { close() }
    override func performMiniaturize(_ sender: Any?) { miniaturize(sender) }

    // 메뉴의 닫기·최소화 항목을 켜 둔다
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(performClose(_:)), #selector(performMiniaturize(_:)): true
        default: super.validateMenuItem(menuItem)
        }
    }
}

/// 맥에서 포스트잇 창을 만들고 다시 보여 준다.
@MainActor
final class StickyAppDelegate: NSObject, NSApplicationDelegate {
    private var window: StickyWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showSticky()
        #if DEBUG
        AppServices.shared.handleDebugLaunchArguments()
        #endif
    }

    /// 창을 닫아도 앱은 남아 있고, Dock 아이콘을 누르면 다시 나온다 (맥 스티커처럼).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSticky()
        return true
    }

    func showSticky() {
        if window == nil { window = makeWindow() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> StickyWindow {
        let services = AppServices.shared
        let window = StickyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.borderless, .resizable, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 260, height: 300)
        window.collectionBehavior = [.fullScreenNone]

        let root = MacStickyRoot()
            .environment(services.settings)
            .environment(services.cloud)
            .modelContainer(services.modelContainer)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []          // 창 크기는 사용자가 정한다
        window.contentView = hosting

        window.center()
        window.setFrameAutosaveName("PostitSticky")   // 위치·크기 기억
        return window
    }
}

/// 창 수준의 설정(접기·항상 위·모서리)을 창에 반영하는 뿌리 뷰.
struct MacStickyRoot: View {
    @Environment(StickySettings.self) private var settings
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage("collapsed") private var collapsed = false

    var body: some View {
        StickyView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowChrome(
                collapsed: collapsed,
                cornerRadius: settings.cornerRadius,
                alwaysOnTop: alwaysOnTop
            ))
    }
}
