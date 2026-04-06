import AppKit
import Carbon

final class HotKeyManager {
    private var carbonRef: EventHotKeyRef?
    private var carbonHandler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(action: @escaping () -> Void) {
        // Strategy 1: Carbon RegisterEventHotKey (no permissions needed)
        registerCarbon(action: action)

        // Strategy 2: NSEvent global monitor (requires Accessibility permission)
        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 0x26,
                   event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .option] {
                    action()
                }
            }
        }

        // Strategy 3: NSEvent local monitor (always works when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 0x26,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .option] {
                action()
                return nil
            }
            return event
        }
    }

    private func registerCarbon(action: @escaping () -> Void) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let actionBox = Unmanaged.passRetained(action as AnyObject)

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let fn = Unmanaged<AnyObject>.fromOpaque(userData).takeUnretainedValue()
                if let action = fn as? () -> Void {
                    DispatchQueue.main.async { action() }
                }
                return noErr
            },
            1, &eventType, actionBox.toOpaque(), &carbonHandler
        )

        let id = EventHotKeyID(signature: OSType(0x4A4B544B), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_J),
            UInt32(cmdKey | optionKey),
            id, GetApplicationEventTarget(), 0, &carbonRef
        )
    }

    deinit {
        if let ref = carbonRef { UnregisterEventHotKey(ref) }
        if let h = carbonHandler { RemoveEventHandler(h) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
