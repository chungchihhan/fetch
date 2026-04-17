import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var store: SnippetStore!
    var settingsWindow: NSWindow?
    var hotKeyManager: HotKeyManager?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let savedPath = UserDefaults.standard.string(forKey: "fetchDataDirectory") ?? ""
        let dir = savedPath.isEmpty ? SnippetStore.defaultDirectory : URL(fileURLWithPath: savedPath)
        store = SnippetStore(storageDirectory: dir)
        applyAppearance(UserDefaults.standard.string(forKey: "fetchColorScheme") ?? "system")
        setupStatusItem()
        setupPopover()
        let savedKC = UserDefaults.standard.integer(forKey: "fetchShortcutKeyCode")
        let savedCM = UserDefaults.standard.integer(forKey: "fetchShortcutCarbonMods")
        let kc = savedKC > 0 ? UInt32(savedKC) : UInt32(kVK_ANSI_F)
        let cm = savedCM > 0 ? UInt32(savedCM) : UInt32(cmdKey | optionKey)
        hotKeyManager = HotKeyManager(keyCode: kc, carbonMods: cm, nsMods: carbonToNSMods(cm)) { [weak self] in
            self?.togglePopover()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutChanged),
            name: .shortcutChanged,
            object: nil
        )

        if UserDefaults.standard.object(forKey: "fetchAutoCheckUpdates") as? Bool ?? true {
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await Updater.shared.checkForUpdates(silent: true)
                _ = self
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                let h: CGFloat = 18
                let w = h * (img.size.width / img.size.height)
                img.size = NSSize(width: w, height: h)
                img.isTemplate = true
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Fetch")
                button.image?.isTemplate = true
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        let savedWidth  = UserDefaults.standard.double(forKey: "fetchWidth")
        let savedHeight = UserDefaults.standard.double(forKey: "fetchHeight")
        popover.contentSize = NSSize(
            width:  savedWidth  > 0 ? savedWidth  : 380,
            height: savedHeight > 0 ? savedHeight : 300
        )
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWidthChanged),
            name: .widthChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    func applyAppearance(_ key: String) {
        let appearance: NSAppearance? = {
            switch key {
            case "light": return NSAppearance(named: .aqua)
            case "dark":  return NSAppearance(named: .darkAqua)
            default:      return nil
            }
        }()
        NSApp.appearance = appearance
        // NSPopover's private window doesn't always inherit NSApp.appearance while visible
        popover?.contentViewController?.view.window?.appearance = appearance
        settingsWindow?.appearance = appearance
    }

    @objc func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView().environment(store)
        )
        window.appearance = NSApp.appearance
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
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
        popover.contentSize = NSSize(width: popover.contentSize.width, height: height)
    }

    @objc func handleShortcutChanged() {
        let kc = UserDefaults.standard.integer(forKey: "fetchShortcutKeyCode")
        let cm = UserDefaults.standard.integer(forKey: "fetchShortcutCarbonMods")
        guard kc > 0 else { return }
        hotKeyManager?.update(keyCode: UInt32(kc), carbonMods: UInt32(cm), nsMods: carbonToNSMods(UInt32(cm)))
    }

    @objc func handleWidthChanged(_ note: Notification) {
        guard let width = note.object as? CGFloat else { return }
        popover.contentSize = NSSize(width: width, height: popover.contentSize.height)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveAll()
    }
}

extension Notification.Name {
    static let heightChanged = Notification.Name("FetchHeightChanged")
    static let widthChanged  = Notification.Name("FetchWidthChanged")
}
