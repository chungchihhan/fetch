import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover!
    var store: SnippetStore!
    var settingsWindow: NSWindow?
    var mainWindow: NSWindow?
    var hotKeyManager: HotKeyManager?
    var eventMonitor: Any?
    private var updateCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let savedPath = UserDefaults.standard.string(forKey: "fetchDataDirectory") ?? ""
        let dir = savedPath.isEmpty ? SnippetStore.defaultDirectory : URL(fileURLWithPath: savedPath)
        store = SnippetStore(storageDirectory: dir)
        applyAppearance(UserDefaults.standard.string(forKey: "fetchColorScheme") ?? "system")
        setupPopover()
        applyDisplayMode(UserDefaults.standard.string(forKey: "fetchDisplayMode") ?? "both")
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIconStyleChanged),
            name: .iconStyleChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayModeChanged),
            name: .displayModeChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopover),
            name: .closePopover,
            object: nil
        )
        applyIconStyle(UserDefaults.standard.string(forKey: "fetchIconStyle") ?? "foxfire")

        if UserDefaults.standard.object(forKey: "fetchAutoCheckUpdates") as? Bool ?? true {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.runUpdateCheck()
            }
            startUpdateCheckTimer()
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(handleSystemWake),
                name: NSWorkspace.didWakeNotification,
                object: nil
            )
        }
    }

    // Re-check daily while the app is running so long-lived sessions
    // still hear about new releases without the user quitting.
    private func startUpdateCheckTimer() {
        updateCheckTimer?.invalidate()
        let timer = Timer(timeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runUpdateCheck() }
        }
        RunLoop.main.add(timer, forMode: .common)
        updateCheckTimer = timer
    }

    @objc private func openProjectPage() {
        if let url = URL(string: "https://github.com/chungchihhan/fetch") {
            NSWorkspace.shared.open(url)
        }
    }

    private func makeStarAccessoryView() -> NSView {
        let button = HoverLinkButton()
        let starAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemYellow,
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .baselineOffset: -2
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
        ]
        let title = NSMutableAttributedString()
        title.append(NSAttributedString(string: "★  ", attributes: starAttrs))
        title.append(NSAttributedString(string: "Star the project to support me", attributes: textAttrs))
        button.attributedTitle = title
        button.target = self
        button.action = #selector(openProjectPage)
        button.sizeToFit()

        // Expand the frame so the title has breathing room; NSButton centers its
        // label inside whatever frame we give it.
        let hPad: CGFloat = 18
        let vPad: CGFloat = 6
        button.frame = NSRect(
            x: 0, y: 0,
            width: button.frame.width + hPad * 2,
            height: button.frame.height + vPad * 2
        )

        // Center the button inside a wider container so NSAlert lays it out nicely.
        let container = NSView(frame: NSRect(
            x: 0, y: 0,
            width: max(300, button.frame.width),
            height: button.frame.height + 6
        ))
        button.frame.origin.x = (container.bounds.width - button.frame.width) / 2
        button.frame.origin.y = 3
        container.addSubview(button)
        return container
    }

    @objc private func handleSystemWake() {
        Task { @MainActor [weak self] in
            // Delay so we don't prompt the instant the user opens the lid —
            // wait for them to settle in and for the network to stabilize.
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            await self?.runUpdateCheck()
        }
    }

    @MainActor
    private func runUpdateCheck() async {
        await Updater.shared.checkForUpdates(silent: true)
        guard Updater.shared.updateAvailable,
              let latest = Updater.shared.latestVersion else { return }
        // Respect "Later" — don't re-nag for the same version until a newer
        // one is released.
        let skipped = UserDefaults.standard.string(forKey: "fetchSkippedUpdateVersion") ?? ""
        if skipped == latest { return }
        promptForUpdate()
    }

    @MainActor
    private func promptForUpdate() {
        guard let version = Updater.shared.latestVersion else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Fetch \(version) is available"
        alert.informativeText = "You're on v\(Updater.shared.currentVersion). Update now? Fetch will quit and reopen when done."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Skip")
        alert.accessoryView = makeStarAccessoryView()

        if alert.runModal() != .alertFirstButtonReturn {
            UserDefaults.standard.set(version, forKey: "fetchSkippedUpdateVersion")
            return
        }

        Updater.shared.installUpdate { success in
            if success {
                Updater.shared.relaunch()
            } else {
                let err = NSAlert()
                err.messageText = "Update failed"
                err.informativeText = Updater.shared.statusMessage
                err.alertStyle = .warning
                err.addButton(withTitle: "OK")
                err.runModal()
            }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
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

    @objc func openMainWindow() {
        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Fetch"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = NSHostingController(
            rootView: MainWindowView().environment(store)
        )
        window.appearance = NSApp.appearance
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openMainWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let mode = UserDefaults.standard.string(forKey: "fetchDisplayMode") ?? "both"
        return mode == "windowOnly"
    }

    @objc func handleClosePopover() {
        if popover?.isShown == true {
            popover.performClose(nil)
        }
    }

    @objc func handleDisplayModeChanged() {
        applyDisplayMode(UserDefaults.standard.string(forKey: "fetchDisplayMode") ?? "both")
    }

    func applyDisplayMode(_ mode: String) {
        switch mode {
        case "menuBarOnly":
            NSApp.setActivationPolicy(.accessory)
            if statusItem == nil { setupStatusItem() }
            mainWindow?.close()
        case "windowOnly":
            NSApp.setActivationPolicy(.regular)
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            if mainWindow == nil || mainWindow?.isVisible == false { openMainWindow() }
        default: // "both"
            NSApp.setActivationPolicy(.regular)
            if statusItem == nil { setupStatusItem() }
        }
    }

    @objc func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = NSHostingController(
            rootView: SettingsView().environment(store)
        )
        window.appearance = NSApp.appearance
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI may resize the window after the initial center() runs; re-center
        // once layout settles so the window stays on screen center.
        DispatchQueue.main.async { window.center() }
        settingsWindow = window
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // With no menu-bar icon, fall back to the main window instead.
            guard let button = statusItem?.button else {
                openMainWindow()
                return
            }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Allow the popover's host window to appear over apps in their own
            // full-screen Space and float above full-screen chrome.
            if let win = popover.contentViewController?.view.window {
                win.collectionBehavior.insert(.canJoinAllSpaces)
                win.collectionBehavior.insert(.fullScreenAuxiliary)
                win.level = .statusBar
                win.makeKey()
            }
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

    @objc func handleIconStyleChanged() {
        applyIconStyle(UserDefaults.standard.string(forKey: "fetchIconStyle") ?? "foxfire")
    }

    func applyIconStyle(_ style: String) {
        let resource: String = {
            switch style {
            case "gloaming": return "icon-gloaming"
            case "smoulder": return "icon-smoulder"
            default:         return "icon-foxfire"
            }
        }()
        guard let url = Bundle.main.url(forResource: resource, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        let bundlePath = Bundle.main.bundlePath
        NSWorkspace.shared.setIcon(image, forFile: bundlePath, options: [])
        NSApp.applicationIconImage = image

        // Nudge LaunchServices so Finder re-reads the bundle's metadata on its own.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: bundlePath)
        NSWorkspace.shared.noteFileSystemChanged(bundlePath)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveAll()
    }
}

extension Notification.Name {
    static let heightChanged      = Notification.Name("FetchHeightChanged")
    static let widthChanged       = Notification.Name("FetchWidthChanged")
    static let iconStyleChanged   = Notification.Name("FetchIconStyleChanged")
    static let displayModeChanged = Notification.Name("FetchDisplayModeChanged")
    static let closePopover       = Notification.Name("FetchClosePopover")
}

// NSButton variant with a soft yellow capsule that brightens on hover.
// Used as the "Star the project" link in the update prompt.
private final class HoverLinkButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private let cornerRadius: CGFloat = 10
    private static let restingColor = NSColor.systemYellow.withAlphaComponent(0.14).cgColor
    private static let hoverColor   = NSColor.systemYellow.withAlphaComponent(0.28).cgColor

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonSetup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        wantsLayer = true
        isBordered = false
        bezelStyle = .inline
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = Self.restingColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
        layer?.backgroundColor = Self.hoverColor
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        layer?.backgroundColor = Self.restingColor
    }
}
