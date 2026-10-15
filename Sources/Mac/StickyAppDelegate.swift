import SwiftUI
import AppKit
import ServiceManagement
import SwiftData
import CoreData

/// 맥: 포스트잇 창 여러 장(최대 6장).
/// 어떤 포스트잇이 열려 있는지는 iCloud로 동기화되므로, 다른 맥에서 열거나 닫으면 여기서도 똑같이 열고 닫는다.
@MainActor
final class StickyAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [UUID: StickyWindow] = [:]
    private var isTerminating = false
    /// 동기화 때문에 닫는 창 (사용자가 닫은 게 아니므로 "닫힘"을 다시 기록하지 않는다)
    private var closingForSync: Set<UUID> = []
    private var syncScheduled = false
    private let hotKey = GlobalHotKey()

    private var context: ModelContext { AppServices.shared.context }

    // MARK: 실행 · 종료

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        AppServices.shared.handleDebugLaunchArguments()   // 창을 만들기 전에 (시험용 초기화)
        #endif
        migrateLocalOpenList()
        if StickyStore.openIDs(in: context).isEmpty {
            StickyStore.setOpen(StickyStore.defaultID, true, in: context)
        }
        syncWindows()
        windows.values.first?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        // 실행하자마자 iCloud에서 최신 내용을 받아온다 (다른 기기에서 연 포스트잇도 함께)
        AppServices.shared.cloud.syncNow(context)

        let center = NotificationCenter.default
        center.addObserver(forName: .postitOpenSticky, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? UUID else { return }
            MainActor.assumeIsolated { self?.open(id) }
        }
        center.addObserver(forName: .postitNewSticky, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.newSticky() }
        }
        center.addObserver(forName: .postitCloseSticky, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? UUID else { return }
            MainActor.assumeIsolated { self?.windows[id]?.close() }
        }
        // 이 맥에서 저장했을 때, iCloud에서 받아왔을 때, 앱으로 돌아왔을 때 창을 맞춘다
        for name in [ModelContext.didSave, NSPersistentCloudKitContainer.eventChangedNotification,
                     NSApplication.didBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleSyncWindows() }
            }
        }

        // 어떤 앱을 쓰고 있든 ⌃⌥P로 포스트잇을 띄우고 입력칸에 커서를 둔다
        hotKey.register { [weak self] in self?.toggleFromHotKey() }

        LoginItem.applyDefaultOnFirstLaunch()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true      // 종료하면서 닫히는 창은 "닫힘"으로 기록하지 않는다
        return .terminateNow
    }

    /// 창을 다 닫아도 앱은 남아 있고, Dock 아이콘을 누르면 다시 나온다 (맥 스티커처럼).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStickies()
        return true
    }

    /// 예전 버전(이 맥에만 기억)에서 열어 두었던 목록을 한 번만 iCloud 열림 상태로 옮긴다.
    private func migrateLocalOpenList() {
        let key = "openStateMigrated"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let local = Set(OpenStickies.ids)
        guard !local.isEmpty else { return }
        for sticky in StickyStore.all(in: context) {
            StickyStore.setOpen(sticky.id, local.contains(sticky.id), in: context)
        }
    }

    // MARK: 동기화된 열림 상태에 창 맞추기

    private func scheduleSyncWindows() {
        guard !syncScheduled else { return }
        syncScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.syncScheduled = false
            self?.syncWindows()
        }
    }

    private func syncWindows() {
        guard !isTerminating else { return }
        let wanted = StickyStore.openIDs(in: context)
        for (id, window) in windows where !wanted.contains(id) {
            closingForSync.insert(id)
            window.close()
        }
        for id in wanted where windows[id] == nil {
            let window = makeWindow(for: id)
            windows[id] = window
            window.orderFront(nil)        // 다른 맥에서 연 포스트잇: 지금 작업을 방해하지 않게 앞에만 둔다
        }
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
        if windows[id] == nil {
            guard ensureRoom() else { return }
            StickyStore.setOpen(id, true, in: context)
            syncWindows()
        }
        windows[id]?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func newSticky() {
        guard ensureRoom() else { return }
        let sticky = StickyStore.create(in: context, paper: AppServices.shared.settings.paper)
        open(sticky.id)
    }

    /// 열린 창이 최대치면 안내하고 false
    private func ensureRoom() -> Bool {
        guard windows.count >= StickyStore.maxOpen else { return true }
        let alert = NSAlert()
        alert.messageText = "포스트잇은 한 번에 \(StickyStore.maxOpen)장까지 열 수 있어요"
        alert.informativeText = "다른 포스트잇을 닫고(⌘W) 다시 열어 주세요."
        alert.runModal()
        return false
    }

    func toggleCollapseOfKeyWindow() {
        guard let id = (NSApp.keyWindow as? StickyWindow)?.stickyID else { return }
        let key = OpenStickies.collapsedKey(id)
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    /// ⌃⌥P: 포스트잇을 지금 보고 있는 모니터로 가져와 앞에 띄운다.
    /// 이미 그 모니터에서 쓰고 있는 중이면 숨긴다.
    private func toggleFromHotKey() {
        let target = Self.screenWithMouse
        let moves = windows.values.compactMap { w in Self.frame(w.frame, movedTo: target).map { (w, $0) } }
        if moves.isEmpty, NSApp.isActive, NSApp.keyWindow is StickyWindow {
            NSApp.hide(nil)
            return
        }
        for (window, frame) in moves { window.setFrame(frame, display: true, animate: false) }
        showStickies()
        if let id = (NSApp.keyWindow as? StickyWindow)?.stickyID {
            NotificationCenter.default.post(name: .postitFocusInput, object: id)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !isTerminating, let window = notification.object as? StickyWindow else { return }
        let id = window.stickyID
        windows[id] = nil
        if closingForSync.remove(id) == nil {
            // 사용자가 닫음 → 다른 맥에서도 닫히도록 기록
            StickyStore.setOpen(id, false, in: context)
        }
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

        // 위치·크기는 이 맥에서 포스트잇마다 기억한다 (재부팅해도 그 자리).
        // 이 맥에서 처음 여는 포스트잇(새로 설치한 맥 포함)은 기본 배열 자리에 둔다.
        let autosave = "PostitSticky.\(id.uuidString)"
        let legacy = id == StickyStore.defaultID ? "PostitSticky" : nil
        let restored = window.setFrameUsingName(autosave) || (legacy.map { window.setFrameUsingName($0) } ?? false)
        if !restored || !isOnScreen(window.frame) {
            window.setFrame(defaultFrame(slot: windows.count), display: false)
        }
        window.setFrameAutosaveName(autosave)
        return window
    }

    /// 기본 배열: 화면 오른쪽 위부터 3장씩 두 줄로 나란히
    /// 기본 배열은 마우스가 있는 모니터의 오른쪽 위부터
    private func defaultFrame(slot: Int) -> NSRect {
        let screen = Self.screenWithMouse.visibleFrame
        let margin: CGFloat = 24, gap: CGFloat = 16, columns = 3
        let width: CGFloat = 340
        let height = min(460, (screen.height - margin * 2 - gap) / 2)
        let column = slot % columns, row = (slot / columns) % 2
        let x = screen.maxX - margin - CGFloat(column + 1) * width - CGFloat(column) * gap
        let top = screen.maxY - margin - CGFloat(row) * (height + gap)
        return NSRect(x: max(screen.minX, x), y: top - height, width: width, height: height)
    }

    /// 지금 마우스가 있는 모니터 (= 사용자가 보고 있는 모니터)
    static var screenWithMouse: NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// 창이 대부분 걸쳐 있는 모니터
    private static func screen(of frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            let ia = a.frame.intersection(frame), ib = b.frame.intersection(frame)
            return ia.width * ia.height < ib.width * ib.height
        }
    }

    /// 다른 모니터에 있는 창을 같은 상대 위치로 옮긴다 (오른쪽 위에 있던 창은 오른쪽 위로).
    /// 이미 그 모니터에 있는 창은 그대로 둔다.
    static func frame(_ frame: NSRect, movedTo target: NSScreen) -> NSRect? {
        guard let source = screen(of: frame), source != target else { return nil }
        let src = source.visibleFrame, dst = target.visibleFrame
        let size = NSSize(width: min(frame.width, dst.width), height: min(frame.height, dst.height))
        func ratio(_ offset: CGFloat, _ room: CGFloat) -> CGFloat { room > 0 ? min(max(offset / room, 0), 1) : 0 }
        let rx = ratio(frame.minX - src.minX, src.width - frame.width)
        let ry = ratio(frame.minY - src.minY, src.height - frame.height)
        return NSRect(x: (dst.minX + rx * (dst.width - size.width)).rounded(),
                      y: (dst.minY + ry * (dst.height - size.height)).rounded(),
                      width: size.width, height: size.height)
    }

    /// 저장된 자리가 지금 연결된 화면 밖이면(모니터를 뺀 경우 등) 기본 배열로
    private func isOnScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
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
