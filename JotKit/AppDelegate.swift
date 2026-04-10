import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var panel: NSPanel?
    let store = SnippetStore()
    var hotKeyManager: HotKeyManager?
    var eventMonitor: Any?
    var isPanel = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent Cmd+Q from quitting (menu bar apps stay alive)
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
            rootView: PopoverContentView()
                .environment(store)
                .onReceive(NotificationCenter.default.publisher(for: .togglePanel)) { [weak self] _ in
                    self?.togglePanel()
                }
        )
        // Close popover on click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }

        // Save all snippets when popover closes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverWillClose),
            name: NSPopover.willCloseNotification,
            object: popover
        )

        // Resize popover/panel when user drags handle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeightChanged),
            name: .heightChanged,
            object: nil
        )
    }

    @objc func togglePopover() {
        guard !isPanel else { panel?.makeKeyAndOrderFront(nil); return }
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
        let size = NSSize(width: 380, height: height)
        if !isPanel {
            popover.contentSize = size
        } else {
            panel?.setContentSize(size)
        }
    }

    func togglePanel() {
        if isPanel {
            // Switch back to popover
            panel?.close()
            panel = nil
            isPanel = false
        } else {
            // Detach to floating panel
            popover.performClose(nil)
            isPanel = true
            let hosting = NSHostingController(
                rootView: PopoverContentView()
                    .environment(store)
                    .onReceive(NotificationCenter.default.publisher(for: .togglePanel)) { [weak self] _ in
                        self?.togglePanel()
                    }
            )
            let storedHeight = UserDefaults.standard.double(forKey: "jotkitHeight")
            let panelHeight = storedHeight > 0 ? storedHeight : 300
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: panelHeight),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            p.contentViewController = hosting
            p.isFloatingPanel = true
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            // Pin to top-right
            if let screen = NSScreen.main {
                let x = screen.visibleFrame.maxX - 390
                let y = screen.visibleFrame.maxY - panelHeight - 10
                p.setFrameOrigin(NSPoint(x: x, y: y))
            }
            p.makeKeyAndOrderFront(nil)
            self.panel = p
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveAll()
    }
}

extension Notification.Name {
    static let togglePanel   = Notification.Name("JotKitTogglePanel")
    static let heightChanged = Notification.Name("JotKitHeightChanged")
}
