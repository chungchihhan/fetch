import SwiftUI
import AppKit

enum SnippetField: Hashable { case title, expire, code, note }

// NSTextField subclass that places cursor at a target index on focus, or at
// the end of the string if no target is set.
private final class EndCursorNSTextField: NSTextField {
    var pendingCursorIndex: Int? = nil

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let editor = currentEditor() {
            let utf16Count = stringValue.utf16.count
            let location = pendingCursorIndex.map { max(0, min($0, utf16Count)) } ?? utf16Count
            editor.selectedRange = NSRange(location: location, length: 0)
            pendingCursorIndex = nil
        }
        return result
    }
}

private struct EndCursorTextField: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var fontSize: CGFloat = 11
    var cursorTargetIndex: Int? = nil
    var onCursorTargetConsumed: () -> Void = {}
    var onBeginEditing: () -> Void = {}
    var placeholder: String = ""
    var textColor: NSColor? = nil
    var alignment: NSTextAlignment = .natural

    func makeNSView(context: Context) -> EndCursorNSTextField {
        let field = EndCursorNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        field.textColor = textColor ?? NSColor.labelColor
        field.focusRingType = .none
        field.placeholderString = placeholder
        field.alignment = alignment
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: EndCursorNSTextField, context: Context) {
        context.coordinator.parent = self
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if nsView.font != font { nsView.font = font }
        if nsView.placeholderString != placeholder { nsView.placeholderString = placeholder }
        if let textColor, nsView.textColor != textColor { nsView.textColor = textColor }
        if nsView.alignment != alignment { nsView.alignment = alignment }
        let isBeingEdited = nsView.currentEditor() != nil
        if !isBeingEdited, nsView.stringValue != text {
            nsView.stringValue = text
        }
        if isFocused, !isBeingEdited {
            nsView.pendingCursorIndex = cursorTargetIndex
            let hadTarget = cursorTargetIndex != nil
            let consumed = onCursorTargetConsumed
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                if hadTarget { consumed() }
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

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onBeginEditing()
        }
    }
}

struct SnippetRowView: View {
    @Binding var snippet: Snippet
    var isFocused: Bool
    var editStep: Int        // 0=browse, 1=title, 2=expire, 3=code, 4=description
    var onTitleChange: (String) -> Void
    var onCodeChange: (String) -> Void
    var onExpireChange: (Date?) -> Void = { _ in }
    var onNoteChange: (String) -> Void = { _ in }
    var onCodeCursorFirstLine: ((Bool) -> Void)? = nil
    var onCodeCursorLastLine: ((Bool) -> Void)? = nil
    var onNoteCursorFirstLine: ((Bool) -> Void)? = nil
    var onEnterEdit: () -> Void = {}
    var onEnterEditAtTitle: (Int) -> Void = { _ in }
    var onEnterEditAtExpire: () -> Void = {}
    var onEnterEditAtCode: (Int) -> Void = { _ in }
    var onEnterEditAtNote: (Int) -> Void = { _ in }
    var onCopy: () -> Void = {}
    var onTitleBeganEditing: () -> Void = {}
    var cursorTargetIndex: Int? = nil
    var onCursorTargetConsumed: () -> Void = {}
    var isCopying: Bool = false

    private var isEditing: Bool { editStep > 0 }
    @State private var isHovering = false
    @State private var copyScale: CGFloat = 1.0
    @State private var expireRawText: String = ""
    @State private var expireParseFailed: Bool = false
    @State private var lastEditingSnapshot: Bool = false
    @AppStorage("fetchCodeWrap") private var codeWrap: Bool = false
    @AppStorage("fetchFontSize") private var storedFontSize: Double = 11
    @AppStorage("fetchTitleFontSize") private var storedTitleFontSize: Double = 11
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @Environment(\.colorScheme) private var colorScheme

    private var fontSize: CGFloat { CGFloat(storedFontSize) }
    private var titleFontSize: CGFloat { CGFloat(storedTitleFontSize) }
    private var noteFontSize: CGFloat { max(9, fontSize - 1) }

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
                    case .ended:
                        isHovering = false
                        NSCursor.arrow.set()
                    }
                }
                .scaleEffect(copyScale)
                .onChange(of: isCopying) { _, copying in
                    guard copying else { return }
                    withAnimation(.easeIn(duration: 0.08)) { copyScale = 0.95 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { copyScale = 1.0 }
                    }
                }
                .onChange(of: isEditing) { _, nowEditing in
                    // Seed the raw expire text from the model when entering edit, and
                    // clear the parse-failed flag so the field doesn't look red until
                    // the user actually types something invalid.
                    if nowEditing && !lastEditingSnapshot {
                        expireRawText = snippet.expiresAt.map { ExpireParser.format($0) } ?? ""
                        expireParseFailed = false
                    }
                    lastEditingSnapshot = nowEditing
                }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
                .frame(minHeight: max(20, titleFontSize * 1.6))

            ZStack(alignment: .topLeading) {
                HighlightedCodeView(
                    code: snippet.code,
                    language: snippet.language,
                    isEditing: isEditing,
                    focusCode: editStep == 3,
                    wrapCode: codeWrap,
                    fontSize: fontSize,
                    onCodeChange: isEditing ? onCodeChange : nil,
                    onCursorFirstLine: onCodeCursorFirstLine,
                    onCursorLastLine: onCodeCursorLastLine,
                    onClick: { idx in onEnterEditAtCode(idx) },
                    cursorTargetIndex: editStep == 3 ? cursorTargetIndex : nil,
                    onCursorTargetConsumed: onCursorTargetConsumed
                )
                .frame(height: codeWrap ? nil : codeViewHeight)
                .mask(CodeFadeMask(enabled: !codeWrap))

                if snippet.code.isEmpty {
                    Text("var")
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.35))
                        .padding(.leading, 7)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
            }
            .padding(EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 14))
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))

            if shouldShowNoteBlock {
                noteBlock
            }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 4) {
            Text("#")
                .font(.system(size: titleFontSize, design: .monospaced))
                .foregroundStyle(hashColor)

            if isEditing {
                EndCursorTextField(
                    text: Binding(get: { snippet.title }, set: { onTitleChange($0) }),
                    isFocused: editStep == 1,
                    fontSize: titleFontSize,
                    cursorTargetIndex: editStep == 1 ? cursorTargetIndex : nil,
                    onCursorTargetConsumed: onCursorTargetConsumed,
                    onBeginEditing: onTitleBeganEditing,
                    placeholder: "title"
                )
            } else {
                Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                    .font(.system(size: titleFontSize, design: .monospaced))
                    .foregroundStyle(.primary.opacity(isFocused ? 0.90 : 0.60))
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        if case .active = phase { NSCursor.iBeam.set() } else { NSCursor.arrow.set() }
                    }
                    .onTapGesture(coordinateSpace: .local) { location in
                        let utf16Count = snippet.title.utf16.count
                        if utf16Count == 0 {
                            onEnterEditAtTitle(0)
                        } else {
                            let charWidth = Self.monospacedCharWidth(fontSize: titleFontSize)
                            let approx = Int((location.x / charWidth).rounded())
                            onEnterEditAtTitle(max(0, min(utf16Count, approx)))
                        }
                    }
                Spacer(minLength: 0)
            }

            noteIndicator
            expireSlot
            CopyIconButton(action: onCopy, isRowFocused: isFocused)
        }
    }

    // Tiny icon shown when the row has a note but isn't focused / editing —
    // signals "there's a description here" without taking screen space. When
    // the row is focused or in edit mode the full description block opens
    // below the code so this indicator hides.
    @ViewBuilder
    private var noteIndicator: some View {
        let hasNote = (snippet.note?.isEmpty == false)
        if hasNote && !isEditing && !isFocused {
            Image(systemName: "text.alignleft")
                .font(.system(size: max(9, titleFontSize - 1), weight: .regular))
                .foregroundStyle(.primary.opacity(0.45))
                .frame(width: 16, height: 16)
                .help(snippet.note ?? "")
        }
    }

    @ViewBuilder
    private var expireSlot: some View {
        if isEditing {
            EndCursorTextField(
                text: Binding(
                    get: { expireRawText },
                    set: { newValue in
                        expireRawText = newValue
                        switch ExpireParser.parse(newValue) {
                        case .success(let date):
                            expireParseFailed = false
                            onExpireChange(date)
                        case .failure:
                            expireParseFailed = true
                        }
                    }
                ),
                isFocused: editStep == 2,
                fontSize: max(9, titleFontSize - 1),
                cursorTargetIndex: editStep == 2 ? cursorTargetIndex : nil,
                onCursorTargetConsumed: onCursorTargetConsumed,
                placeholder: "optional, +90d",
                textColor: expireParseFailed ? NSColor.systemRed : NSColor.secondaryLabelColor,
                alignment: .right
            )
            .frame(width: 116)
            .help("Optional. Formats: YYYY-MM-DD, YYYY/MM/DD, +Nd (e.g. +30d)")
            .contentShape(Rectangle())
            .onTapGesture { onEnterEditAtExpire() }
        } else if let date = snippet.expiresAt {
            Text(ExpireParser.badge(date))
                .font(.system(size: max(9, titleFontSize - 1), design: .monospaced))
                .foregroundStyle(expireColor(for: ExpireParser.status(date)))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(expireColor(for: ExpireParser.status(date)).opacity(0.14))
                )
                .help(ExpireParser.format(date))
        }
    }

    private var shouldShowNoteBlock: Bool {
        if isEditing { return true }                                  // always while editing
        if isFocused, let n = snippet.note, !n.isEmpty { return true } // expand when focused
        return false                                                  // otherwise hide (indicator on title row)
    }

    private var noteBlock: some View {
        ZStack(alignment: .topLeading) {
            PlainTextView(
                text: Binding(get: { snippet.note ?? "" }, set: { onNoteChange($0) }),
                isEditing: isEditing,
                isFocused: editStep == 4,
                fontSize: noteFontSize,
                placeholder: "note (optional)",
                onTextChange: isEditing ? onNoteChange : nil,
                onCursorFirstLine: onNoteCursorFirstLine,
                onClick: { idx in onEnterEditAtNote(idx) },
                cursorTargetIndex: editStep == 4 ? cursorTargetIndex : nil,
                onCursorTargetConsumed: onCursorTargetConsumed
            )
            // NSTextView has no native placeholder; overlay one while empty.
            // Layout uses the same insets as PlainTextView's container (2pt) +
            // line fragment padding (5pt) so the placeholder lines up with the
            // caret/text exactly.
            if (snippet.note ?? "").isEmpty {
                Text("note (optional)")
                    .font(.system(size: noteFontSize))
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.leading, 7)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
            }
        }
        .padding(EdgeInsets(top: 5, leading: 7, bottom: 5, trailing: 7))
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func expireColor(for status: ExpireParser.Status) -> Color {
        switch status {
        case .expired: return Color.red
        case .soon:    return Color.orange
        case .ok:      return Color.primary.opacity(0.55)
        }
    }

    private static func monospacedCharWidth(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return NSAttributedString(string: "M", attributes: [.font: font]).size().width
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

private struct CopyIconButton: View {
    var action: () -> Void
    var isRowFocused: Bool = false
    @State private var isHovering = false
    @State private var didFire = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"

    var body: some View {
        Image(systemName: "doc.on.doc")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(
                isHovering
                    ? Color.styleAccent(colorScheme, style: iconStyle)
                    : .primary.opacity(isRowFocused ? 0.50 : 0.30)
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
            .help("Copy snippet (⌘C)")
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

private struct CodeFadeMask: View {
    var enabled: Bool
    var fadeDistance: CGFloat = 28

    var body: some View {
        Rectangle().fill(.white)
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [.clear, .white],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: fadeDistance)
                    .opacity(enabled ? 1 : 0)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
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
