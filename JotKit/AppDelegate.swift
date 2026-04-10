import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let store = SnippetStore()
    var hotKeyManager: HotKeyManager?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        hotKeyManager = HotKeyManager { [weak self] in
            self?.togglePopover()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "JotKit")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 300)
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView().environment(store)
        )
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverWillClose),
            name: NSPopover.willCloseNotification,
            object: popover
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeightChanged),
            name: .heightChanged,
            object: nil
        )
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
            }
        }
    }

    @objc func popoverWillClose() {
        store.saveAll()
    }

    @objc func handleHeightChanged(_ note: Notification) {
        guard let height = note.object as? CGFloat else { return }
        popover.contentSize = NSSize(width: 380, height: height)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveAll()
    }
}

extension Notification.Name {
    static let heightChanged = Notification.Name("JotKitHeightChanged")
}
