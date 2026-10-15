import AppKit
import Carbon.HIToolbox

/// 다른 앱을 쓰는 중에도 동작하는 단축키 ⌃⌥P.
/// Carbon 단축키는 손쉬운 사용 권한 없이도 샌드박스 앱에서 쓸 수 있다.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static var action: (() -> Void)?

    static let displayName = "⌃⌥P"

    func register(_ action: @escaping () -> Void) {
        Self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotKey.action?() } }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x5053_5449), id: 1)   // 'PSTI'
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
