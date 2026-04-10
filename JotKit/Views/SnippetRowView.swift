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

    func makeNSView(context: Context) -> EndCursorNSTextField {
        let field = EndCursorNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        field.textColor = NSColor.labelColor
        field.focusRingType = .none
        field.placeholderString = ""
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: EndCursorNSTextField, context: Context) {
        context.coordinator.parent = self
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

    private var isEditing: Bool { editStep > 0 }
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "#78c9ab").opacity(isFocused ? 0.80 : 0.45))

                if isEditing {
                    EndCursorTextField(
                        text: Binding(get: { snippet.title }, set: { onTitleChange($0) }),
                        isFocused: editStep == 1
                    )
                    .frame(height: 16)
                } else {
                    Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary.opacity(isFocused ? 0.90 : 0.60))
                    Spacer(minLength: 0)
                    // Copy icon — visible when row is focused in browse mode
                    if isFocused {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet.code, forType: .string)
                            NotificationCenter.default.post(name: .toastMessage, object: "Copied")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                        .help("Copy code")
                    }
                }
            }

            // Code block
            HighlightedCodeView(
                code: snippet.code,
                language: snippet.language,
                isEditing: isEditing,
                focusCode: editStep == 2,
                onCodeChange: isEditing ? onCodeChange : nil,
                onCursorFirstLine: onCursorFirstLine
            )
            .frame(height: codeViewHeight)
            .padding(7)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
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

    // 1–5 visible lines, then vertical scroll
    private var codeViewHeight: CGFloat {
        let lineCount = snippet.code.isEmpty ? 1 : snippet.code.components(separatedBy: "\n").count
        let visibleLines = max(1, min(lineCount, 5))
        return CGFloat(visibleLines) * 16 + 4   // 16pt per line + 4pt inset
    }

    private var backgroundFill: Color {
        if isEditing { return Color(hex: "#d4855c").opacity(0.12) }
        if isFocused { return Color(hex: "#78c9ab").opacity(0.16) }
        if isHovering { return Color.primary.opacity(0.07) }
        return .clear
    }

    private var borderColor: Color {
        if isEditing { return Color(hex: "#d4855c").opacity(0.75) }
        if isFocused { return Color(hex: "#78c9ab").opacity(0.70) }
        if isHovering { return Color.primary.opacity(0.20) }
        return Color.primary.opacity(0.10)
    }
}

