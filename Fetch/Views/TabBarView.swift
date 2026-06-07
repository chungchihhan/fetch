import SwiftUI
import AppKit

struct TabBarView: View {
    @Binding var activeTab: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SnippetStore.self) private var store
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var toastMessage: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil
    @State private var isEditingTabName = false
    @State private var editingName = ""

    private var editAccent: Color {
        colorScheme == .dark ? Color(hex: "#e6cf5f") : Color(hex: "#b08a1e")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Tabs — left-aligned
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    Button("⌘\(i + 1)") { activeTab = i }
                    .buttonStyle(TabButtonStyle(isActive: activeTab == i))
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: NSCursor.pointingHand.set()
                        case .ended:  NSCursor.arrow.set()
                        }
                    }
                }
            }

            Spacer()

            // Top-right indicator: toast takes precedence, otherwise "Edit Mode" while editing.
            if let msg = toastMessage {
                ShineText(
                    text: msg,
                    baseColor: Color.styleAccent(colorScheme, style: iconStyle)
                )
                .transition(.opacity)
                .padding(.trailing, 12)
            } else if store.editStep > 0 {
                ShineText(text: "Edit Mode", baseColor: editAccent)
                    .padding(.trailing, 12)
            } else if isEditingTabName {
                TabNameTextField(
                    text: $editingName,
                    onCommit: { confirmTabRename(name: $0) },
                    onCancel: cancelTabRename
                )
                .frame(width: 80, height: 18)
                .padding(.trailing, 12)
            } else {
                Text(store.tabNames[store.activeTab])
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.55))
                    .padding(.trailing, 12)
                    .onTapGesture { startTabRename() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: toastMessage)
        .onChange(of: store.activeTab) { _, _ in
            if isEditingTabName { cancelTabRename() }
        }
        .overlay(Divider(), alignment: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .toastMessage)) { note in
            toastMessage = note.object as? String
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { toastMessage = nil }
            }
        }
    }

    private func startTabRename() {
        editingName = store.tabNames[store.activeTab]
        isEditingTabName = true
    }

    private func confirmTabRename(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        store.renameTab(store.activeTab, name: trimmed.isEmpty ? "Tab \(store.activeTab + 1)" : trimmed)
        isEditingTabName = false
    }

    private func cancelTabRename() {
        isEditingTabName = false
    }
}

// Monospaced label that gets a soft moving "shine" sweep across the
// glyphs every few seconds. Used for toast/edit-mode hints.
private struct ShineText: View {
    let text: String
    let baseColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let cycle = 2.6
            let phase = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
            let highlight = phase * 1.6 - 0.3   // sweeps -0.3 → 1.3

            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Self.gradient(at: highlight, base: baseColor))
        }
    }

    private static func gradient(at h: Double, base: Color) -> LinearGradient {
        let center = max(0, min(1, h))
        let lo = max(0, min(1, h - 0.20))
        let hi = max(0, min(1, h + 0.20))
        return LinearGradient(
            stops: [
                .init(color: base,                  location: 0),
                .init(color: base,                  location: lo),
                .init(color: .white.opacity(0.85), location: center),
                .init(color: base,                  location: hi),
                .init(color: base,                  location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// NSTextField-backed text field that reliably fires onCommit (Enter or click-away)
// and onCancel (Esc) via AppKit delegate — SwiftUI's @FocusState doesn't detect
// focus loss when clicks land on NSEvent-monitored views like the snippet list.
private struct TabNameTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: (String) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> AutoFocusTextField {
        let field = AutoFocusTextField()
        field.delegate = context.coordinator
        field.isBezeled = false
        field.drawsBackground = false
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.alignment = .right
        field.focusRingType = .none
        field.stringValue = text
        return field
    }

    func updateNSView(_ nsView: AutoFocusTextField, context: Context) {
        if !context.coordinator.isEditing { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCommit: onCommit, onCancel: onCancel) }

    // Requests focus the moment it joins a window — avoids async timing races.
    final class AutoFocusTextField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                window.makeFirstResponder(self)
                self.selectText(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onCommit: (String) -> Void
        var onCancel: () -> Void
        var isEditing = false

        init(onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        func controlTextDidBeginEditing(_ obj: Notification) { isEditing = true }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard isEditing else { return }  // ignore spurious end-editing before user types
            isEditing = false
            guard let field = obj.object as? NSTextField else { return }
            let movement = (obj.userInfo?["NSTextMovement"] as? Int) ?? 0
            if movement == 17 { // NSEscapeTextMovement
                onCancel()
            } else {
                onCommit(field.stringValue)
            }
        }
    }
}

struct TabButtonStyle: ButtonStyle {
    var isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        TabButtonBody(configuration: configuration, isActive: isActive)
    }
}

private struct TabButtonBody: View {
    let configuration: ButtonStyleConfiguration
    var isActive: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchTabFontSize") private var tabFontSize: Double = 10
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var isHovering = false

    private var accent: Color { Color.styleAccent(colorScheme, style: iconStyle) }

    var body: some View {
        configuration.label
            .font(.system(size: CGFloat(tabFontSize), design: .monospaced))
            .foregroundStyle(isActive ? accent : .primary.opacity(isHovering ? 0.80 : 0.55))
            .padding(.vertical, 3)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? accent.opacity(0.15) : (isHovering ? Color.primary.opacity(0.07) : .clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? accent.opacity(0.40) : (isHovering ? Color.primary.opacity(0.18) : .clear), lineWidth: 1)
                    )
            )
            .onHover { isHovering = $0 }
    }
}

// Convenience hex color init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8) & 0xff) / 255
        let b = Double(int & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }

    static func styleAccent(_ scheme: ColorScheme, style: String) -> Color {
        switch style {
        case "gloaming":
            return scheme == .dark ? Color(hex: "#82b5d4") : Color(hex: "#2f6a9f")
        case "smoulder":
            return scheme == .dark ? Color(hex: "#d48a8a") : Color(hex: "#9f2f3f")
        default: // foxfire
            return scheme == .dark ? Color(hex: "#78c9ab") : Color(hex: "#2f8f6a")
        }
    }
}
