import SwiftUI
import AppKit

/// 테두리 없는 포스트잇 창.
/// 기본 NSWindow는 테두리가 없으면 키보드 입력을 받지 못하고 ⌘W·⌘M도 동작하지 않아서 직접 허용한다.
final class StickyWindow: NSWindow {
    var stickyID = StickyStore.defaultID

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

    // MARK: ⌘Z 되돌리기
    // 글자 입력의 되돌리기와 할 일 변경(추가·체크·삭제·라벨)의 되돌리기를 따로 둔다.
    // 입력칸에 되돌릴 글자가 있으면 글자부터, 없으면 할 일 변경을 되돌린다.

    /// 입력칸(필드 편집기)이 쓰는 글자 전용 되돌리기
    let textUndo = UndoManager()
    private var dataUndo: UndoManager? {
        MainActor.assumeIsolated { AppServices.shared.context.undoManager }
    }
    private var isEditingText: Bool { firstResponder is NSTextView }

    override var undoManager: UndoManager? {
        isEditingText ? textUndo : dataUndo
    }

    @objc func undo(_ sender: Any?) {
        if isEditingText, textUndo.canUndo { textUndo.undo() } else { dataUndo?.undo() }
    }

    @objc func redo(_ sender: Any?) {
        if isEditingText, textUndo.canRedo { textUndo.redo() } else { dataUndo?.redo() }
    }

    override func performClose(_ sender: Any?) { close() }
    override func performMiniaturize(_ sender: Any?) { miniaturize(sender) }

    // 메뉴의 닫기·최소화 항목을 켜 둔다
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(performClose(_:)), #selector(performMiniaturize(_:)): true
        case #selector(undo(_:)): (isEditingText && textUndo.canUndo) || dataUndo?.canUndo == true
        case #selector(redo(_:)): (isEditingText && textUndo.canRedo) || dataUndo?.canRedo == true
        default: super.validateMenuItem(menuItem)
        }
    }
}

