import SwiftUI
import AppKit
import ServiceManagement
import SwiftData

/// 맥: 포스트잇 창 여러 장(최대 6장)을 만들고, 열어 둔 포스트잇을 다음 실행 때 그대로 다시 연다.
@MainActor
final class StickyAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [UUID: StickyWindow] = [:]
    private var isTerminating = false
    private let hotKey = GlobalHotKey()

    // MARK: 실행 · 종료

    func applicationDidFinishLaunching(_ notification: Notification) {
        let existing = Set(StickyStore.all(in: AppServices.shared.context).map(\.id))
        var ids = OpenStickies.ids.filter { existing.contains($0) }
        if ids.isEmpty { ids = [StickyStore.defaultID] }
        for id in ids.prefix(StickyStore.maxOpen) { open(id) }

        let center = NotificationCenter.default
        center.addObserver(forName: .postitOpenSticky, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? UUID else { return }
            MainActor.assumeIsolated { self?.open(id) }
        }
        center.addObserver(forName: .postitCloseSticky, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? UUID else { return }
            MainActor.assumeIsolated { self?.windows[id]?.close() }
        }

        // 어떤 앱을 쓰고 있든 ⌃⌥P로 포스트잇을 띄우고 입력칸에 커서를 둔다
        hotKey.register { [weak self] in self?.toggleFromHotKey() }

        LoginItem.applyDefaultOnFirstLaunch()

        #if DEBUG
        AppServices.shared.handleDebugLaunchArguments()
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true      // 종료하면서 닫히는 창은 "열어 둔 목록"에서 빼지 않는다
        return .terminateNow
    }

    /// 창을 다 닫아도 앱은 남아 있고, Dock 아이콘을 누르면 다시 나온다 (맥 스티커처럼).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStickies()
        return true
    }

    // MARK: 창 열기 · 닫기

    /// 열려 있는 포스트잇을 모두 앞으로. 하나도 없으면 기본 포스트잇을 연다.
    func showStickies() {
        if windows.isEmpty {
            open(StickyStore.defaultID)
        } else {
            for window in windows.values { window.orderFront(nil) }
            (NSApp.keyWindow as? StickyWindow ?? windows.values.first)?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate()
    }

    func open(_ id: UUID) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        guard windows.count < StickyStore.maxOpen else {
            let alert = NSAlert()
            alert.messageText = "포스트잇은 한 번에 \(StickyStore.maxOpen)장까지 열 수 있어요"
            alert.informativeText = "다른 포스트잇을 닫고(⌘W) 다시 열어 주세요."
            alert.runModal()
            return
        }
        let window = makeWindow(for: id)
        windows[id] = window
        saveOpenList()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func newSticky() {
        let services = AppServices.shared
        let sticky = StickyStore.create(in: services.context, paper: services.settings.paper)
        open(sticky.id)
    }

    func toggleCollapseOfKeyWindow() {
        guard let id = (NSApp.keyWindow as? StickyWindow)?.stickyID else { return }
        let key = OpenStickies.collapsedKey(id)
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    private func toggleFromHotKey() {
        if NSApp.isActive, NSApp.keyWindow is StickyWindow {
            NSApp.hide(nil)
            return
        }
        showStickies()
        if let id = (NSApp.keyWindow as? StickyWindow)?.stickyID {
            NotificationCenter.default.post(name: .postitFocusInput, object: id)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !isTerminating, let window = notification.object as? StickyWindow else { return }
        windows[window.stickyID] = nil
        saveOpenList()
    }

    private func saveOpenList() {
        OpenStickies.ids = Array(windows.keys)
    }

    private func makeWindow(for id: UUID) -> StickyWindow {
        let services = AppServices.shared
        let window = StickyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.borderless, .resizable, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.stickyID = id
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 260, height: 300)
        window.collectionBehavior = [.fullScreenNone]

        let root = MacStickyRoot(stickyID: id)
            .environment(services.settings)
            .environment(services.cloud)
            .modelContainer(services.modelContainer)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []          // 창 크기는 사용자가 정한다
        window.contentView = hosting

        // 위치·크기는 포스트잇마다 기억. 처음 여는 포스트잇은 앞 창에서 조금 비켜서 연다.
        let autosave = "PostitSticky.\(id.uuidString)"
        let legacy = id == StickyStore.defaultID ? "PostitSticky" : nil
        if !window.setFrameUsingName(autosave) && !(legacy.map { window.setFrameUsingName($0) } ?? false) {
            if let front = NSApp.keyWindow as? StickyWindow ?? windows.values.first {
                window.setFrameTopLeftPoint(NSPoint(x: front.frame.minX + 28, y: front.frame.maxY - 28))
            } else {
                window.center()
            }
        }
        window.setFrameAutosaveName(autosave)
        return window
    }
}

/// 창 수준의 설정(접기·항상 위·모서리)을 창에 반영하는 뿌리 뷰.
struct MacStickyRoot: View {
    let stickyID: UUID
    @Environment(StickySettings.self) private var settings
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage private var collapsed: Bool
    @Query private var stickies: [Sticky]

    init(stickyID: UUID) {
        self.stickyID = stickyID
        _collapsed = AppStorage(wrappedValue: false, OpenStickies.collapsedKey(stickyID))
        _stickies = Query(filter: #Predicate<Sticky> { $0.id == stickyID })
    }

    var body: some View {
        StickyView(stickyID: stickyID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowChrome(
                stickyID: stickyID,
                collapsed: collapsed,
                cornerRadius: settings.cornerRadius,
                alwaysOnTop: alwaysOnTop
            ))
            // 다른 기기에서 이 포스트잇을 지우면 이 창도 닫는다
            .onChange(of: stickies.isEmpty) { _, gone in
                if gone { NotificationCenter.default.post(name: .postitCloseSticky, object: stickyID) }
            }
    }
}

/// 로그인 시 자동 실행 (시스템 설정 > 일반 > 로그인 항목에 표시됨)
@MainActor
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("로그인 항목 설정 실패: \(error)")
        }
    }

    /// 처음 실행할 때 한 번만 기본으로 켠다. 이후에는 사용자가 정한 대로 둔다.
    static func applyDefaultOnFirstLaunch() {
        let key = "loginItemDefaultApplied"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
