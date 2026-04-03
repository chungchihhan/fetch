import SwiftUI

enum SnippetField: Hashable { case title, code }

struct SnippetRowView: View {
    @Binding var snippet: Snippet
    var isFocused: Bool
    var isEditing: Bool
    var onTitleChange: (String) -> Void
    var onCodeChange: (String) -> Void

    // Drives Tab-switching: when isEditing turns true, .title is focused.
    // The user presses Tab → macOS moves to the next key view (the NSTextView
    // inside HighlightedCodeView) via the standard AppKit responder chain.
    @FocusState private var focusedField: SnippetField?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row: "# title"
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "#89b4fa").opacity(isFocused ? 0.6 : 0.3))
                if isEditing {
                    TextField("", text: Binding(
                        get: { snippet.title },
                        set: { onTitleChange($0) }
                    ))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .title)
                } else {
                    Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(isFocused ? 0.9 : 0.35))
                }
            }

            // Code block. NSTextView is a natural key view successor to
            // the title TextField — Tab moves into it automatically.
            HighlightedCodeView(
                code: snippet.code,
                language: snippet.language,
                isEditing: isEditing,
                onCodeChange: isEditing ? onCodeChange : nil
            )
            .frame(minHeight: 28)
            .padding(7)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(8)
        .background(backgroundFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        // Auto-focus title field when this row enters edit mode
        .onChange(of: isEditing) { _, editing in
            focusedField = editing ? .title : nil
        }
    }

    private var backgroundFill: Color {
        if isEditing { return Color(hex: "#f9e2af").opacity(0.05) }
        if isFocused { return Color(hex: "#89b4fa").opacity(0.07) }
        return .clear
    }

    private var borderColor: Color {
        if isEditing { return Color(hex: "#f9e2af").opacity(0.30) }
        if isFocused { return Color(hex: "#89b4fa").opacity(0.35) }
        return .clear
    }
}
