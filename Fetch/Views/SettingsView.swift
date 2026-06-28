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
    @AppStorage("fetchConfirmDelete") private var confirmDelete: Bool = true
    @AppStorage("fetchAutoPaste") private var autoPaste: Bool = false
    @State private var updater = Updater.shared
    @State private var selectedTab = 0

    private var displayPath: String {
        dataDirectory.isEmpty ? SnippetStore.defaultDirectory.path : dataDirectory
    }

    var body: some View {
        ZStack {
            // Explicit frosted backdrop — avoids relying on SwiftUI's default
            // TabView chrome, which renders inconsistently across macOS versions
            // and window styles (glass in some builds, plain in others).
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.55)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }
                    .tag(0)
                shortcutsTab
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                    .tag(1)
                aboutTab
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(2)
            }
            .frame(width: 480, height: 520)
        }
        .onChange(of: colorSchemeKey) { _, newValue in
            (NSApp.delegate as? AppDelegate)?.applyAppearance(newValue)
        }
        .onChange(of: iconStyle) { _, _ in
            NotificationCenter.default.post(name: .iconStyleChanged, object: nil)
        }
        .onChange(of: displayMode) { _, _ in
            NotificationCenter.default.post(name: .displayModeChanged, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { note in
            if let tab = note.object as? Int { selectedTab = tab }
        }
    }

    private var shortcutsTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                shortcutSection("Global", firstInList: true, rows: [
                    (shortcutDisplay, "Toggle Fetch"),
                ])
                shortcutSection("Browse", rows: [
                    ("⌘1 – ⌘6", "Switch tabs"),
                    ("↑ / ↓", "Navigate snippets"),
                    ("↵", "Copy code only"),
                    ("⌘C", "Copy title + code"),
                    ("⌘E", "Enter edit mode"),
                    ("⌘N", "New snippet"),
                    ("⌘D", "Delete snippet"),
                    ("⌥↑ / ⌥↓", "Reorder up / down"),
                    ("⌘Z / ⌘⇧Z", "Undo / Redo"),
                    ("⌘= / ⌘−", "Increase / decrease size"),
                    ("⌘,", "Open Settings"),
                    ("Esc", "Close popover"),
                ])
                shortcutSection("Edit", rows: [
                    ("Tab / ⇧Tab", "Switch title / code"),
                    ("↵", "Save and exit"),
                    ("Esc", "Save and exit"),
                    ("⇧↵", "New line in code"),
                    ("⌘E", "Exit edit"),
                ])
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, firstInList: Bool = false, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title, firstInList: firstInList)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    shortcutRow(row.0, row.1)
                    if idx < rows.count - 1 {
                        Divider()
                            .padding(.leading, 176)
                            .opacity(0.6)
                    }
                }
            }
            .background(.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.1), lineWidth: 0.5))
        }
    }

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(Array(keys.components(separatedBy: " / ").enumerated()), id: \.offset) { i, part in
                    if i > 0 {
                        Text("/")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    keyBadge(part)
                }
            }
            .frame(width: 148, alignment: .trailing)
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.primary.opacity(0.18), lineWidth: 0.5)
            )
    }

    private var aboutTab: some View {
        VStack(spacing: 10) {
            if let nsImage = NSApp.applicationIconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 96, height: 96)
            }
            Text("Fetch")
                .font(.system(size: 22, weight: .semibold))
            Text("v\(updater.currentVersion)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("Fast, keyboard-driven code snippet manager\nfor your Mac menu bar.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            Divider().padding(.vertical, 6)

            Link(destination: URL(string: "https://github.com/chungchihhan/fetch")!) {
                Label("github.com/chungchihhan/fetch", systemImage: "arrow.up.right.square")
                    .font(.system(size: 13, design: .monospaced))
            }
            Text("MIT © 2026 Chih-Han Chung")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                settingSection("Appearance", firstInList: true) {
                    settingRow {
                        Text("Theme")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $colorSchemeKey) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 185)
                    }
                    Divider()
                    settingRow {
                        Text("Display Mode")
                            .font(.system(size: 13, design: .monospaced))
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
                            .font(.system(size: 13, design: .monospaced))
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
                }

                settingSection("Editor") {
                    settingRow {
                        Text("Code Wrap")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $codeWrap)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    Divider()
                    settingRow {
                        Text("Tab Font Size")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Slider(value: $tabFontSize, in: 8...20, step: 1)
                                .frame(width: 140)
                            Text("\(Int(tabFontSize)) pt")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 48, alignment: .leading)
                        }
                    }
                    Divider()
                    settingRow {
                        Text("Title Font Size")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Slider(value: $titleFontSize, in: 8...20, step: 1)
                                .frame(width: 140)
                            Text("\(Int(titleFontSize)) pt")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 48, alignment: .leading)
                        }
                    }
                    Divider()
                    settingRow {
                        Text("Code Font Size")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Slider(value: $fontSize, in: 8...20, step: 1)
                                .frame(width: 140)
                            Text("\(Int(fontSize)) pt")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 48, alignment: .leading)
                        }
                    }
                }

                settingSection("Behavior") {
                    settingRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Confirm Before Delete")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("Ask to confirm when pressing ⌘D")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $confirmDelete)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    Divider()
                    settingRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Auto-paste on Enter")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("Close Fetch and paste into your last focused input")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $autoPaste)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                settingSection("System") {
                    settingRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Data Folder")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(displayPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 240, alignment: .leading)
                        }
                        Spacer()
                        Button("Browse…") { pickFolder() }
                    }
                    Divider()
                    settingRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Global Shortcut")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("Click box to record")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        ShortcutRecorderView(
                            keyCode: $shortcutKeyCode,
                            carbonMods: $shortcutCarbonMods,
                            display: $shortcutDisplay
                        )
                        .frame(width: 120, height: 30)
                    }
                }

                settingSection("Updates") {
                    settingRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Version \(updater.currentVersion)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if !updater.statusMessage.isEmpty {
                                Text(updater.statusMessage)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 240, alignment: .leading)
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
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $autoCheckUpdates)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(_ title: String, firstInList: Bool = false) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
            Spacer()
        }
        .padding(.top, firstInList ? 16 : 22)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func settingSection<Content: View>(_ title: String, firstInList: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title, firstInList: firstInList)
            VStack(spacing: 0) {
                content()
            }
            .background(.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.1), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center) { content() }
            .padding(.horizontal, 14)
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
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
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
