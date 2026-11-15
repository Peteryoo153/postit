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
        resize(window, animate: !isFirstApply, isFirstApply: isFirstApply)
        DispatchQueue.main.async { window.invalidateShadow() }
    }

    /// 윗변을 고정한 채로 높이만 바꾼다 (스티커가 위로 말려 올라가듯).
    private func resize(_ window: NSWindow, animate: Bool, isFirstApply: Bool) {
        var frame = window.frame
        let top = frame.maxY
        let defaults = UserDefaults.standard

        if collapsed {
            // 펼쳤을 때 돌아갈 높이를 기억한다 (제대로 펼쳐진 크기일 때만)
            if frame.height >= Self.expandedMinSize.height {
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
            // 실행할 때(처음 적용)는 기억해 둔 창 크기를 그대로 둔다. 너무 작을 때만 고친다.
            // 접힌 띠를 펼칠 때는 언제나 접기 전 높이로 되돌린다.
            // (예전 버전에서 띠 높이가 40이어서 높이로 판단하면 펼쳐지지 않는 일이 있었다)
            if isFirstApply && frame.height >= Self.expandedMinSize.height { return }
            frame.size.height = saved >= Self.expandedMinSize.height ? saved : 560
        }
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true, animate: animate)
    }
}
