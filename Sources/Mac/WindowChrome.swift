import SwiftUI
import AppKit

/// 창 수준 설정을 실제 창에 반영한다: 접기/펼치기 높이, 항상 위, 모서리에 맞춘 그림자.
struct WindowChrome: NSViewRepresentable {
    static let collapsedHeight: CGFloat = 30
    private static let expandedMinSize = NSSize(width: 260, height: 300)

    var stickyID: UUID
    var collapsed: Bool
    var cornerRadius: Double
    var alwaysOnTop: Bool
    var appearance: AppearanceMode = .system

    final class Coordinator {
        var appliedCollapsed: Bool?
        var appliedRadius: Double?
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
        window.level = alwaysOnTop ? .floating : .normal
        let wanted: NSAppearance? = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        if window.appearance?.name != wanted?.name { window.appearance = wanted }

        if coordinator.appliedRadius != cornerRadius {
            coordinator.appliedRadius = cornerRadius
            // 그림자가 새로 그려진 모서리를 따라가도록 (그린 뒤에 다시 계산)
            DispatchQueue.main.async { window.invalidateShadow() }
        }

        guard coordinator.appliedCollapsed != collapsed else { return }
        let isFirstApply = coordinator.appliedCollapsed == nil
        coordinator.appliedCollapsed = collapsed
        resize(window, animate: !isFirstApply)
        DispatchQueue.main.async { window.invalidateShadow() }
    }

    /// 윗변을 고정한 채로 높이만 바꾼다 (스티커가 위로 말려 올라가듯).
    private func resize(_ window: NSWindow, animate: Bool) {
        var frame = window.frame
        let top = frame.maxY
        let defaults = UserDefaults.standard

        if collapsed {
            if frame.height > Self.collapsedHeight + 1 {
                defaults.set(frame.height, forKey: OpenStickies.expandedHeightKey(stickyID))
            }
            window.minSize = NSSize(width: Self.expandedMinSize.width, height: Self.collapsedHeight)
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: Self.collapsedHeight)
            frame.size.height = Self.collapsedHeight
        } else {
            window.minSize = Self.expandedMinSize
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                    height: CGFloat.greatestFiniteMagnitude)
            let saved = defaults.double(forKey: OpenStickies.expandedHeightKey(stickyID))
            // 이미 펼쳐진 크기면 그대로 둔다 (실행할 때 기억해 둔 창 크기를 덮어쓰지 않게)
            guard frame.height <= Self.collapsedHeight + 1 else { return }
            frame.size.height = max(saved > 0 ? saved : 560, Self.expandedMinSize.height)
        }
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true, animate: animate)
    }
}
