import SwiftUI
import AppKit

/// Lightweight multi-line text editor for the description / note field.
/// Mirrors `HighlightedCodeView`'s focus + cursor-line plumbing but without
/// syntax highlighting. Wraps to its proposed width.
struct PlainTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditing: Bool
    var isFocused: Bool
    var fontSize: CGFloat = 11
    var placeholder: String = ""
    var onTextChange: ((String) -> Void)? = nil
    var onCursorFirstLine: ((Bool) -> Void)? = nil
    var onCursorLastLine: ((Bool) -> Void)? = nil
    var onClick: ((Int) -> Void)? = nil
    var cursorTargetIndex: Int? = nil
    var onCursorTargetConsumed: (() -> Void)? = nil

    private static let containerInsetX: CGFloat = 2
    private static let containerInsetY: CGFloat = 2
    private static let lineFragmentPadding: CGFloat = 5

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ClickableTextView()
        textView.onMouseDownInBrowse = { [weak coord = context.coordinator] charIndex in
            coord?.onClick?(charIndex)
        }
        let font = NSFont.systemFont(ofSize: fontSize)
        textView.isRichText = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(
            width: Self.containerInsetX,
            height: Self.containerInsetY
        )
        textView.font = font
        textView.textColor = NSColor.secondaryLabelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.typingAttributes = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: font
        ]
        textView.delegate = context.coordinator
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        return scrollView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let proposedWidth = proposal.width, proposedWidth > 1 else { return nil }
        let usable = max(
            1,
            proposedWidth - 2 * Self.containerInsetX - 2 * Self.lineFragmentPadding
        )
        let font = NSFont.systemFont(ofSize: fontSize)
        let measured = text.isEmpty ? placeholder : text
        let attr = NSAttributedString(string: measured.isEmpty ? " " : measured, attributes: [.font: font])
        let rect = attr.boundingRect(
            with: NSSize(width: usable, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let h = max(16, ceil(rect.height) + 2 * Self.containerInsetY)
        return CGSize(width: proposedWidth, height: h)
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ClickableTextView else { return }

        let coord = context.coordinator
        coord.onTextChange = onTextChange
        coord.onCursorFirstLine = onCursorFirstLine
        coord.onCursorLastLine = onCursorLastLine
        coord.onClick = onClick

        if textView.isEditable != isEditing {
            textView.isEditable = isEditing
            textView.isSelectable = isEditing
            textView.window?.invalidateCursorRects(for: textView)
        }

        let font = NSFont.systemFont(ofSize: fontSize)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: font
            ]
        }

        let wasFocused = coord.wasFocused
        coord.wasFocused = isFocused

        if isFocused && isEditing && textView.window?.firstResponder !== textView {
            let target = cursorTargetIndex
            let onConsumed = onCursorTargetConsumed
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                let clamped = target.map { max(0, min($0, textView.string.utf16.count)) } ?? textView.string.utf16.count
                textView.setSelectedRange(NSRange(location: clamped, length: 0))
                textView.scrollRangeToVisible(NSRange(location: clamped, length: 0))
                coord.reportLineFlags(tv: textView)
                if target != nil { onConsumed?() }
            }
        } else if !isFocused && wasFocused && isEditing {
            if textView.window?.firstResponder === textView {
                textView.window?.makeFirstResponder(nil)
            }
        }

        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: ((String) -> Void)?
        var onCursorFirstLine: ((Bool) -> Void)?
        var onCursorLastLine: ((Bool) -> Void)?
        var onClick: ((Int) -> Void)?
        var wasFocused: Bool = false

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onTextChange?(tv.string)
            reportLineFlags(tv: tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            guard tv.window?.firstResponder === tv else { return }
            reportLineFlags(tv: tv)
        }

        func reportLineFlags(tv: NSTextView) {
            guard let lm = tv.layoutManager, let tc = tv.textContainer else {
                onCursorFirstLine?(true)
                onCursorLastLine?(true)
                return
            }
            lm.ensureLayout(for: tc)
            let totalGlyphs = lm.numberOfGlyphs
            guard totalGlyphs > 0 else {
                onCursorFirstLine?(true)
                onCursorLastLine?(true)
                return
            }
            let cursorPos = tv.selectedRange().location
            var glyphIdx = lm.glyphIndexForCharacter(at: cursorPos)
            if glyphIdx >= totalGlyphs { glyphIdx = totalGlyphs - 1 }
            var lineGlyphRange = NSRange()
            _ = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: &lineGlyphRange)
            onCursorFirstLine?(lineGlyphRange.location == 0)
            let lineEnd = lineGlyphRange.location + lineGlyphRange.length
            onCursorLastLine?(lineEnd >= totalGlyphs)
        }
    }
}

private final class ClickableTextView: NSTextView {
    var onMouseDownInBrowse: ((Int) -> Void)?

    override func resetCursorRects() {
        if isEditable { super.resetCursorRects() }
        else { addCursorRect(bounds, cursor: .iBeam) }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isEditable { super.cursorUpdate(with: event) }
        else { NSCursor.iBeam.set() }
    }

    override func mouseDown(with event: NSEvent) {
        if isEditable {
            super.mouseDown(with: event)
        } else {
            let p = convert(event.locationInWindow, from: nil)
            onMouseDownInBrowse?(characterIndexForInsertion(at: p))
        }
    }
}
