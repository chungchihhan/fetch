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
            // Tabs — left-aligned. fixedSize keeps the row at its natural width
            // so the ⌘N labels never get compressed into a second line; the
            // right-side name area absorbs any width squeeze instead.
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
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)

            // Right indicator — flexible, takes all remaining space, content trailing-aligned.
            // Priority: toast > Edit Mode > tab name field > tab name label.
            Group {
                if let msg = toastMessage {
                    ShineText(
                        text: msg,
                        baseColor: Color.styleAccent(colorScheme, style: iconStyle)
                    )
                    .transition(.opacity)
                } else if store.editStep > 0 {
                    ShineText(text: "Edit Mode", baseColor: editAccent)
                } else if isEditingTabName {
                    TabNameTextField(
                        text: $editingName,
                        onCommit: { confirmTabRename(name: $0) },
                        onCancel: cancelTabRename
                    )
                    .frame(height: 18)
                } else {
                    Text(store.tabNames[store.activeTab])
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.55))
                        .lineLimit(1)
                        .onTapGesture { startTabRename() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
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

    func makeNSView(context: Context) -> TabNameTextView {
        let view = TabNameTextView()
        view.coordinator = context.coordinator
        view.delegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        // Natural (left) layout — NOT right alignment. Right alignment hangs
        // trailing whitespace past the container's right edge where it gets
        // clipped. The view hugs its content width (see intrinsicContentSize)
        // and SwiftUI pins it to the trailing edge, so it still reads as
        // right-aligned while keeping trailing spaces on-screen.
        view.alignment = .natural
        view.isEditable = true
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.maximumNumberOfLines = 1
        view.textContainer?.lineBreakMode = .byClipping
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isHorizontallyResizable = true
        view.isVerticallyResizable = false
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.string = text
        return view
    }

    func updateNSView(_ nsView: TabNameTextView, context: Context) {
        if !context.coordinator.isEditing { nsView.string = text }
    }

    // Size the field to its content width (trailing spaces included) so SwiftUI
    // doesn't stretch it full-width. The trailing-aligned parent then pins this
    // compact field to the right corner — reading as right-aligned.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TabNameTextView, context: Context) -> CGSize? {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nsView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        let width = ceil((nsView.string as NSString).size(withAttributes: attrs).width) + 3
        return CGSize(width: width, height: 18)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel)
    }

    // NSTextView preserves trailing whitespace; NSTextField's cell strips it in right-aligned mode.
    final class TabNameTextView: NSTextView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                window.makeFirstResponder(self)
                self.selectAll(nil)
            }
        }

        // Hug the content width *including* trailing whitespace.
        // NSString.size(withAttributes:) counts trailing spaces (unlike the
        // line-fragment used rect), so the field stays wide enough to show
        // the caret sitting after them. +3 leaves room for the caret itself.
        override var intrinsicContentSize: NSSize {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
            let width = ceil((string as NSString).size(withAttributes: attrs).width)
            return NSSize(width: width + 3, height: NSView.noIntrinsicMetric)
        }

        override func didChangeText() {
            super.didChangeText()
            invalidateIntrinsicContentSize()
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 36: coordinator?.commit(string: string)  // Enter
            case 53: coordinator?.cancel()                // Esc
            default: super.keyDown(with: event)
            }
        }

        override func resignFirstResponder() -> Bool {
            let result = super.resignFirstResponder()
            if result { coordinator?.commit(string: string) }
            return result
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onCommit: (String) -> Void
        var onCancel: () -> Void
        var isEditing = false

        init(text: Binding<String>, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        func textDidBeginEditing(_ notification: Notification) { isEditing = true }

        // Push each keystroke to the binding so SwiftUI re-runs sizeThatFits and
        // the field grows/shrinks to match — keeping it pinned at the right edge.
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }

        func commit(string: String) {
            guard isEditing else { return }
            isEditing = false
            onCommit(string)
        }

        func cancel() {
            guard isEditing else { return }
            isEditing = false
            onCancel()
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
            .lineLimit(1)
            .fixedSize()
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
