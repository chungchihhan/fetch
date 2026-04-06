import AppKit

final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(action: @escaping () -> Void) {
        // Prompt user for accessibility permission (required for global hotkey)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        // Global monitor: ⌘J from any app (requires Accessibility permission)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 0x26,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                action()
            }
        }

        // Local monitor: ⌘J when JotKit itself is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 0x26,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                action()
                return nil
            }
            return event
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
