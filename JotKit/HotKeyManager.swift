import AppKit
import Carbon

final class HotKeyManager {
    private var carbonRef: EventHotKeyRef?
    private var carbonHandler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let action: () -> Void

    init(keyCode: UInt32, carbonMods: UInt32, nsMods: NSEvent.ModifierFlags,
         action: @escaping () -> Void) {
        self.action = action
        setupCarbonHandler(action: action)
        registerCarbonKey(keyCode: keyCode, carbonMods: carbonMods)
        registerNSMonitors(keyCode: keyCode, nsMods: nsMods)
    }

    func update(keyCode: UInt32, carbonMods: UInt32, nsMods: NSEvent.ModifierFlags) {
        if let ref = carbonRef { UnregisterEventHotKey(ref); carbonRef = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
        registerCarbonKey(keyCode: keyCode, carbonMods: carbonMods)
        registerNSMonitors(keyCode: keyCode, nsMods: nsMods)
    }

    private func setupCarbonHandler(action: @escaping () -> Void) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let box = Unmanaged.passRetained(action as AnyObject)
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let fn = Unmanaged<AnyObject>.fromOpaque(userData).takeUnretainedValue()
                if let action = fn as? () -> Void { DispatchQueue.main.async { action() } }
                return noErr
            },
            1, &eventType, box.toOpaque(), &carbonHandler
        )
    }

    private func registerCarbonKey(keyCode: UInt32, carbonMods: UInt32) {
        let id = EventHotKeyID(signature: OSType(0x4A4B544B), id: 1)
        RegisterEventHotKey(keyCode, carbonMods, id, GetApplicationEventTarget(), 0, &carbonRef)
    }

    private func registerNSMonitors(keyCode: UInt32, nsMods: NSEvent.ModifierFlags) {
        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return }
                if event.keyCode == keyCode,
                   event.modifierFlags.intersection(.deviceIndependentFlagsMask) == nsMods {
                    self.action()
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == keyCode,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == nsMods {
                self.action()
                return nil
            }
            return event
        }
    }

    deinit {
        if let ref = carbonRef { UnregisterEventHotKey(ref) }
        if let h = carbonHandler { RemoveEventHandler(h) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
    }
}

// Convert Carbon modifier flags → NSEvent.ModifierFlags
func carbonToNSMods(_ carbon: UInt32) -> NSEvent.ModifierFlags {
    var flags: NSEvent.ModifierFlags = []
    if carbon & UInt32(cmdKey)     != 0 { flags.insert(.command) }
    if carbon & UInt32(optionKey)  != 0 { flags.insert(.option)  }
    if carbon & UInt32(shiftKey)   != 0 { flags.insert(.shift)   }
    if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
    return flags
}
