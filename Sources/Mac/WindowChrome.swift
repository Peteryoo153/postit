import SwiftUI
import AppKit

/// 스티커처럼 보이도록 창 장식을 걷어내고, 접기/펼치기에 맞춰 창 높이를 바꾼다.
/// 닫기·최소화·확대 버튼을 숨기고, 창 배경 어디를 잡아도 옮길 수 있게 한다.
/// 닫기는 ⌘W, 최소화는 ⌘M으로 그대로 쓸 수 있다.
struct WindowChrome: NSViewRepresentable {
    static let collapsedHeight: CGFloat = 40
    private static let expandedHeightKey = "expandedHeight"

    var collapsed: Bool

    final class Coordinator {
        var appliedCollapsed: Bool?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window, context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window, context.coordinator) }
    }

    private func configure(_ window: NSWindow?, _ coordinator: Coordinator) {
        guard let window else { return }
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(kind)?.isHidden = true
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true

        guard coordinator.appliedCollapsed != collapsed else { return }
        let isFirstApply = coordinator.appliedCollapsed == nil
        coordinator.appliedCollapsed = collapsed
        resize(window, animate: !isFirstApply)
    }

    /// 윗변을 고정한 채로 높이만 바꾼다 (스티커가 위로 말려 올라가듯).
    private func resize(_ window: NSWindow, animate: Bool) {
        var frame = window.frame
        let top = frame.maxY
        let defaults = UserDefaults.standard

        if collapsed {
            if frame.height > Self.collapsedHeight + 1 {
                defaults.set(frame.height, forKey: Self.expandedHeightKey)
            }
            frame.size.height = Self.collapsedHeight
        } else {
            let saved = defaults.double(forKey: Self.expandedHeightKey)
            guard frame.height <= Self.collapsedHeight + 1 || saved > 0 else { return }
            frame.size.height = saved > 0 ? saved : 560
        }
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true, animate: animate)
    }
}
