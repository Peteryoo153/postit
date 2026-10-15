import SwiftUI
import AppKit

/// 스티커처럼 보이도록 창 장식을 걷어낸다.
/// 닫기·최소화·확대 버튼을 숨기고, 창 배경 어디를 잡아도 옮길 수 있게 한다.
/// 닫기는 ⌘W, 최소화는 ⌘M으로 그대로 쓸 수 있다.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(kind)?.isHidden = true
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
    }
}
