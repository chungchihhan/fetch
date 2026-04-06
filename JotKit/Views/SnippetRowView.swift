import SwiftUI
import AppKit

enum SnippetField: Hashable { case title, code }

struct SnippetRowView: View {
    @Binding var snippet: Snippet
    var isFocused: Bool
    var editStep: Int        // 0=browse, 1=title edit, 2=code edit
    var onTitleChange: (String) -> Void
    var onCodeChange: (String) -> Void
    var onCursorFirstLine: ((Bool) -> Void)? = nil

    @FocusState private var focusedField: SnippetField?

    private var isEditing: Bool { editStep > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
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
                    .foregroundStyle(.white.opacity(0.9))
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .title)
                } else {
                    Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(isFocused ? 0.9 : 0.35))
                    Spacer(minLength: 0)
                    // Copy icon — visible when row is focused in browse mode
                    if isFocused {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet.code, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.35))
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
        .onAppear {
            focusedField = editStep == 1 ? .title : nil
        }
        .onChange(of: editStep) { _, step in
            focusedField = step == 1 ? .title : nil
        }
    }

    // 1–5 visible lines, then vertical scroll
    private var codeViewHeight: CGFloat {
        let lineCount = snippet.code.isEmpty ? 1 : snippet.code.components(separatedBy: "\n").count
        let visibleLines = max(1, min(lineCount, 5))
        return CGFloat(visibleLines) * 16 + 4   // 16pt per line + 4pt inset
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
