import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @Environment(SnippetStore.self) var store
    @AppStorage("fetchColorScheme") private var colorSchemeKey: String = "system"
    @AppStorage("fetchDataDirectory") private var dataDirectory: String = ""
    @AppStorage("fetchCodeWrap") private var codeWrap: Bool = false
    @AppStorage("fetchFontSize") private var fontSize: Double = 11
    @AppStorage("fetchTitleFontSize") private var titleFontSize: Double = 11
    @AppStorage("fetchTabFontSize") private var tabFontSize: Double = 10
    @AppStorage("fetchShortcutKeyCode") private var shortcutKeyCode: Int = Int(kVK_ANSI_F)
    @AppStorage("fetchShortcutCarbonMods") private var shortcutCarbonMods: Int = Int(cmdKey | optionKey)
    @AppStorage("fetchShortcutDisplay") private var shortcutDisplay: String = "⌘ ⌥ F"
    @AppStorage("fetchAutoCheckUpdates") private var autoCheckUpdates: Bool = true
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @AppStorage("fetchDisplayMode") private var displayMode: String = "both"
    @State private var updater = Updater.shared

    private var displayPath: String {
        dataDirectory.isEmpty ? SnippetStore.defaultDirectory.path : dataDirectory
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 400)
        .onChange(of: colorSchemeKey) { _, newValue in
            (NSApp.delegate as? AppDelegate)?.applyAppearance(newValue)
        }
        .onChange(of: iconStyle) { _, _ in
            NotificationCenter.default.post(name: .iconStyleChanged, object: nil)
        }
        .onChange(of: displayMode) { _, _ in
            NotificationCenter.default.post(name: .displayModeChanged, object: nil)
        }
    }

    private var shortcutsTab: some View {
        VStack(spacing: 0) {
            sectionHeader("Global", firstInList: true)
            shortcutRow(shortcutDisplay, "Toggle Fetch")

            sectionHeader("Browse")
            shortcutRow("⌘1 – ⌘6", "Switch tabs")
            shortcutRow("↑ / ↓", "Navigate snippets")
            shortcutRow("↵", "Copy code only")
            shortcutRow("⌘C", "Copy title with code")
            shortcutRow("⌘E", "Enter edit mode")
            shortcutRow("⌘N", "New snippet")
            shortcutRow("⌘D", "Delete focused snippet")
            shortcutRow("⌥↑ / ⌥↓", "Reorder snippet up / down")
            shortcutRow("⌘Z / ⌘⇧Z", "Undo / Redo")
            shortcutRow("⌘= / ⌘-", "Increase / decrease text size")
            shortcutRow("⌘,", "Open Settings")
            shortcutRow("Esc", "Close popover")

            sectionHeader("Edit")
            shortcutRow("Tab / ⇧Tab", "Switch title / code")
            shortcutRow("↵", "Save and exit")
            shortcutRow("Esc", "Save and exit")
            shortcutRow("⇧↵", "New line in code")
            shortcutRow("⌘E", "Exit edit")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        HStack(alignment: .center) {
            Text(keys)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.80))
                .frame(width: 120, alignment: .leading)
            Text(description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 5)
    }

    private var aboutTab: some View {
        VStack(spacing: 10) {
            if let nsImage = NSApp.applicationIconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 96, height: 96)
            }
            Text("Fetch")
                .font(.system(size: 20, weight: .semibold))
            Text("v\(updater.currentVersion)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("Fast, keyboard-driven code snippet manager\nfor your Mac menu bar.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            Divider().padding(.vertical, 6)

            Link(destination: URL(string: "https://github.com/chungchihhan/fetch")!) {
                Label("github.com/chungchihhan/fetch", systemImage: "arrow.up.right.square")
                    .font(.system(size: 11, design: .monospaced))
            }
            Text("MIT © 2026 Chih-Han Chung")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private var generalTab: some View {
        VStack(spacing: 0) {
                sectionHeader("Appearance", firstInList: true)

                settingRow {
                    Text("Theme")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $colorSchemeKey) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Divider()

                settingRow {
                    Text("Display Mode")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $displayMode) {
                        Text("Both").tag("both")
                        Text("Menu Bar Only").tag("menuBarOnly")
                        Text("Window Only").tag("windowOnly")
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                Divider()

                settingRow {
                    Text("Icon Style")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $iconStyle) {
                        Text("Foxfire").tag("foxfire")
                        Text("Gloaming").tag("gloaming")
                        Text("Smoulder").tag("smoulder")
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                sectionHeader("Editor")

                settingRow {
                    Text("Code Wrap")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $codeWrap)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()

                settingRow {
                    Text("Tab Font Size")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Slider(value: $tabFontSize, in: 8...20, step: 1)
                            .frame(width: 120)
                        Text("\(Int(tabFontSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                }

                Divider()

                settingRow {
                    Text("Title Font Size")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Slider(value: $titleFontSize, in: 8...20, step: 1)
                            .frame(width: 120)
                        Text("\(Int(titleFontSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                }

                Divider()

                settingRow {
                    Text("Code Font Size")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Slider(value: $fontSize, in: 8...20, step: 1)
                            .frame(width: 120)
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                }

                sectionHeader("System")

                settingRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Data Folder")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(displayPath)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200, alignment: .leading)
                    }
                    Spacer()
                    Button("Browse…") { pickFolder() }
                }

                Divider()

                settingRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Global Shortcut")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("Click box to record")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: $shortcutKeyCode,
                        carbonMods: $shortcutCarbonMods,
                        display: $shortcutDisplay
                    )
                    .frame(width: 100, height: 26)
                }

                sectionHeader("Updates")

                settingRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Version \(updater.currentVersion)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if !updater.statusMessage.isEmpty {
                            Text(updater.statusMessage)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 200, alignment: .leading)
                        }
                    }
                    Spacer()
                    if updater.updateReady {
                        Button("Relaunch") { updater.relaunch() }
                    } else if updater.updateAvailable {
                        Button(updater.isInstalling ? "Installing…" : "Update Now") {
                            updater.installUpdate()
                        }
                        .disabled(updater.isInstalling)
                    } else {
                        Button(updater.isChecking ? "Checking…" : "Check Now") {
                            Task { await updater.checkForUpdates() }
                        }
                        .disabled(updater.isChecking)
                    }
                }

                Divider()

                settingRow {
                    Text("Auto-check for Updates")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $autoCheckUpdates)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func sectionHeader(_ title: String, firstInList: Bool = false) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
            Spacer()
        }
        .padding(.top, firstInList ? 16 : 22)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func settingRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center) { content() }
            .padding(.vertical, 12)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for Fetch data"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        dataDirectory = url.path
        store.changeDirectory(to: url)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var carbonMods: Int
    @Binding var display: String

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let v = ShortcutRecorderNSView()
        v.coordinator = context.coordinator
        v.displayString = display
        return v
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.displayString = display
        if !nsView.isRecording { nsView.needsDisplay = true }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: ShortcutRecorderView
        init(_ parent: ShortcutRecorderView) { self.parent = parent }

        func save(keyCode: UInt32, carbonMods: UInt32, display: String) {
            parent.keyCode = Int(keyCode)
            parent.carbonMods = Int(carbonMods)
            parent.display = display
            UserDefaults.standard.set(Int(keyCode),    forKey: "fetchShortcutKeyCode")
            UserDefaults.standard.set(Int(carbonMods), forKey: "fetchShortcutCarbonMods")
            NotificationCenter.default.post(name: .shortcutChanged, object: nil)
        }
    }
}

final class ShortcutRecorderNSView: NSView {
    var coordinator: ShortcutRecorderView.Coordinator?
    var displayString: String = "⌘ ⌥ F"
    var isRecording = false
    private var preRecordDisplay: String = ""

    // Physical key label by key code — bypasses IME entirely
    private static let keyLabel: [UInt32: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
        11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T",
        18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5", 24:"=", 25:"9", 26:"7",
        27:"-", 28:"8", 29:"0", 30:"]", 31:"O", 32:"U", 33:"[", 34:"I", 35:"P",
        37:"L", 38:"J", 39:"'", 40:"K", 41:";", 42:"\\", 43:",", 44:"/",
        45:"N", 46:"M", 47:".", 50:"`",
        36:"↩", 48:"⇥", 49:"Space", 51:"⌫",
        123:"←", 124:"→", 125:"↓", 126:"↑",
        122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6",
        98:"F7", 100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12",
    ]

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor = isRecording ? .selectedControlColor : .controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let label = displayString.isEmpty ? "…" : displayString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2,
                             y: (bounds.height - sz.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        preRecordDisplay = displayString
        displayString = ""
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // Show modifiers live as the user holds them
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        displayString = parts.joined(separator: " ")
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        if event.keyCode == 53 {  // Escape — cancel
            displayString = preRecordDisplay
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyChar = Self.keyLabel[UInt32(event.keyCode)]
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control),
              let keyChar else { return }

        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyChar)
        let display = parts.joined(separator: " ")

        var cm: UInt32 = 0
        if flags.contains(.command) { cm |= UInt32(cmdKey) }
        if flags.contains(.option)  { cm |= UInt32(optionKey) }
        if flags.contains(.shift)   { cm |= UInt32(shiftKey) }
        if flags.contains(.control) { cm |= UInt32(controlKey) }

        coordinator?.save(keyCode: UInt32(event.keyCode), carbonMods: cm, display: display)

        isRecording = false
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { displayString = preRecordDisplay }
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }
}
