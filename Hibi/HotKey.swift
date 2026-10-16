import Carbon.HIToolbox

/// One system-wide keyboard shortcut. Uses Carbon's RegisterEventHotKey, which needs no Accessibility permission.
/// Keep it for the life of the app (AppDelegate does): Carbon holds an unretained pointer to it.
@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// - Parameters:
    ///   - keyCode: a virtual key code, e.g. `kVK_ANSI_H`
    ///   - modifiers: Carbon modifier flags, e.g. `controlKey | cmdKey`
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }   // Carbon calls this on the main thread
            return OSStatus(noErr)
        }, 1, &pressed, context, &handlerRef)
        guard installed == OSStatus(noErr) else { return nil }

        let id = EventHotKeyID(signature: OSType(0x4869_6269), id: 1)   // "Hibi"
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == OSStatus(noErr) else {   // another app already owns this shortcut
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }
}
