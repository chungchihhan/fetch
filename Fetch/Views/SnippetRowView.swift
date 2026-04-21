import SwiftUI
import AppKit

enum SnippetField: Hashable { case title, code }

// NSTextField subclass that places cursor at end on focus
private final class EndCursorNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let editor = currentEditor() {
            editor.selectedRange = NSRange(location: stringValue.utf16.count, length: 0)
        }
        return result
    }
}

private struct EndCursorTextField: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var fontSize: CGFloat = 11

    func makeNSView(context: Context) -> EndCursorNSTextField {
        let field = EndCursorNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        field.textColor = NSColor.labelColor
        field.focusRingType = .none
        field.placeholderString = ""
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: EndCursorNSTextField, context: Context) {
        context.coordinator.parent = self
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if nsView.font != font { nsView.font = font }
        let isBeingEdited = nsView.currentEditor() != nil
        if !isBeingEdited, nsView.stringValue != text {
            nsView.stringValue = text
        }
        if isFocused, !isBeingEdited {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EndCursorTextField
        init(_ parent: EndCursorTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

struct SnippetRowView: View {
    @Binding var snippet: Snippet
    var isFocused: Bool
    var editStep: Int        // 0=browse, 1=title edit, 2=code edit
    var onTitleChange: (String) -> Void
    var onCodeChange: (String) -> Void
    var onCursorFirstLine: ((Bool) -> Void)? = nil
    var onEnterEdit: () -> Void = {}

    private var isEditing: Bool { editStep > 0 }
    @State private var isHovering = false
    @State private var wrappedCodeHeight: CGFloat = 32
    @AppStorage("fetchCodeWrap") private var codeWrap: Bool = false
    @AppStorage("fetchFontSize") private var storedFontSize: Double = 11
    @AppStorage("fetchTitleFontSize") private var storedTitleFontSize: Double = 11
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @Environment(\.colorScheme) private var colorScheme

    private var fontSize: CGFloat { CGFloat(storedFontSize) }
    private var titleFontSize: CGFloat { CGFloat(storedTitleFontSize) }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            GripHandle()
                .opacity(isHovering || isFocused ? 0.55 : 0.25)
                .draggable(snippet.id.uuidString) {
                    GripHandle().opacity(0.8).padding(8)
                }

            rowContent
                .padding(8)
                .background(backgroundFill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isHovering = true
                        if !isEditing { NSCursor.pointingHand.set() }
                    case .ended:
                        isHovering = false
                        NSCursor.arrow.set()
                    }
                }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: titleFontSize, design: .monospaced))
                    .foregroundStyle(hashColor)

                if isEditing {
                    EndCursorTextField(
                        text: Binding(get: { snippet.title }, set: { onTitleChange($0) }),
                        isFocused: editStep == 1,
                        fontSize: titleFontSize
                    )
                    .frame(height: titleFontSize * 1.4)
                } else {
                    Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                        .font(.system(size: titleFontSize, design: .monospaced))
                        .foregroundStyle(.primary.opacity(isFocused ? 0.90 : 0.60))
                    Spacer(minLength: 0)
                    if isFocused {
                        EditIconButton(action: onEnterEdit)
                    }
                }
            }

            // Code block
            HighlightedCodeView(
                code: snippet.code,
                language: snippet.language,
                isEditing: isEditing,
                focusCode: editStep == 2,
                wrapCode: codeWrap,
                fontSize: fontSize,
                onCodeChange: isEditing ? onCodeChange : nil,
                onCursorFirstLine: onCursorFirstLine,
                onHeightChange: codeWrap ? { wrappedCodeHeight = $0 } : nil
            )
            .frame(height: codeWrap ? max(codeViewHeight, wrappedCodeHeight) : codeViewHeight)
            .onChange(of: codeWrap) { _, wrap in
                if wrap { wrappedCodeHeight = codeViewHeight }
            }
            .padding(7)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    // 1–5 visible lines, then vertical scroll
    private var codeViewHeight: CGFloat {
        let lineCount = snippet.code.isEmpty ? 1 : snippet.code.components(separatedBy: "\n").count
        let visibleLines = max(1, min(lineCount, 5))
        return CGFloat(visibleLines) * (fontSize * 1.5) + 4
    }

    private var editAccent: Color {
        colorScheme == .dark ? Color(hex: "#e6cf5f") : Color(hex: "#b08a1e")
    }

    private var backgroundFill: Color {
        if isEditing { return editAccent.opacity(0.16) }
        if isFocused { return Color.styleAccent(colorScheme, style: iconStyle).opacity(0.16) }
        if isHovering { return Color.primary.opacity(0.07) }
        return .clear
    }

    private var hashColor: Color {
        if colorScheme == .dark {
            return Color.styleAccent(colorScheme, style: iconStyle).opacity(isFocused ? 0.90 : 0.45)
        } else {
            return Color.primary.opacity(isFocused ? 0.90 : 0.60)
        }
    }

    private var borderColor: Color {
        if isEditing { return editAccent.opacity(0.75) }
        if isFocused { return Color.styleAccent(colorScheme, style: iconStyle).opacity(0.70) }
        if isHovering { return Color.primary.opacity(0.20) }
        return Color.primary.opacity(0.10)
    }
}

private struct EditIconButton: View {
    var action: () -> Void
    @State private var isHovering = false
    @State private var didFire = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"

    var body: some View {
        Image(systemName: "square.and.pencil")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(
                isHovering
                    ? Color.styleAccent(colorScheme, style: iconStyle)
                    : .primary.opacity(0.50)
            )
            .shadow(
                color: isHovering
                    ? Color.styleAccent(colorScheme, style: iconStyle).opacity(0.6)
                    : .clear,
                radius: 4
            )
            .scaleEffect(isHovering ? 1.18 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: isHovering)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .help("Edit snippet (⌘E)")
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !didFire {
                            didFire = true
                            action()
                        }
                    }
                    .onEnded { _ in didFire = false }
            )
    }
}

// Three-dot vertical grip used as the drag handle.
struct GripHandle: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().frame(width: 2.5, height: 2.5)
            }
        }
        .foregroundStyle(.primary)
        .frame(width: 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
        }
    }
}
