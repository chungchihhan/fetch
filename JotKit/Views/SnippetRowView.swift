import SwiftUI

enum SnippetField: Hashable { case title, code }

struct SnippetRowView: View {
    @Binding var snippet: Snippet
    var isFocused: Bool
    var editStep: Int        // 0=browse, 1=title edit, 2=code edit
    var onTitleChange: (String) -> Void
    var onCodeChange: (String) -> Void

    @FocusState private var focusedField: SnippetField?

    private var isEditing: Bool { editStep > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            HighlightedCodeView(
                code: snippet.code,
                language: snippet.language,
                isEditing: isEditing,
                focusCode: editStep == 2,
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
        .onChange(of: editStep) { _, step in
            focusedField = step == 1 ? .title : nil
        }
    }

    private var backgroundFill: Color {
        if isEditing { return Color(hex: "#f9e2af").opacity(0.12) }
        if isFocused { return Color(hex: "#89b4fa").opacity(0.20) }
        return .clear
    }

    private var borderColor: Color {
        if isEditing { return Color(hex: "#f9e2af").opacity(0.70) }
        if isFocused { return Color(hex: "#89b4fa").opacity(0.80) }
        return Color.white.opacity(0.08)
    }
}
