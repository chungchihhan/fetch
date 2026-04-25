import SwiftUI
import Highlightr

struct HighlightedCodeView: NSViewRepresentable {
    var code: String
    var language: String
    var isEditing: Bool
    var focusCode: Bool = false
    var wrapCode: Bool = false
    var fontSize: CGFloat = 11
    var onCodeChange: ((String) -> Void)?
    var onCursorFirstLine: ((Bool) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private static let highlightr: Highlightr? = Highlightr()
    private static var currentTheme: String = ""

    private var theme: String { colorScheme == .dark ? "atom-one-dark" : "atom-one-light" }

    // Insets we apply on the NSTextView; the wrapping width is
    // proposedWidth - 2*containerInset.x - 2*lineFragmentPadding.
    private static let containerInsetX: CGFloat = 2
    private static let containerInsetY: CGFloat = 2
    private static let lineFragmentPadding: CGFloat = 5  // NSTextContainer default

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PointerCursorTextView()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isRichText = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(
            width: Self.containerInsetX,
            height: Self.containerInsetY
        )
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]
        textView.delegate = context.coordinator

        // Default to non-wrapping; updateNSView reconfigures when wrapCode is on.
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                              height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = []
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

    // SwiftUI asks for our height given a proposed width. In wrap mode we
    // return the natural wrapped content height — covers both browse and
    // edit; while editing the row grows with whatever the user types,
    // because each keystroke re-runs the SwiftUI body with new `code` and
    // SwiftUI re-asks sizeThatFits. In non-wrap mode we return nil so the
    // parent's .frame(height:) drives the size.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: NSScrollView,
                      context: Context) -> CGSize? {
        guard wrapCode,
              let proposedWidth = proposal.width,
              proposedWidth > 1 else {
            return nil
        }
        let usable = max(
            1,
            proposedWidth - 2 * Self.containerInsetX - 2 * Self.lineFragmentPadding
        )
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attr = NSAttributedString(string: code, attributes: [.font: font])
        let rect = attr.boundingRect(
            with: NSSize(width: usable, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let h = max(16, ceil(rect.height) + 2 * Self.containerInsetY)
        return CGSize(width: proposedWidth, height: h)
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync highlight theme with current appearance (shared singleton).
        if Self.currentTheme != theme {
            Self.highlightr?.setTheme(to: theme)
            Self.currentTheme = theme
        }

        // Sync wrap mode. Only mutate AppKit state when something actually
        // changed; re-setting the same values triggers layout invalidation.
        let wasWrapping = textView.textContainer?.widthTracksTextView ?? false
        let wrapChanged = wasWrapping != wrapCode
        if wrapChanged {
            textView.textContainer?.widthTracksTextView = wrapCode
            textView.isHorizontallyResizable = !wrapCode
            textView.autoresizingMask = wrapCode ? [.width] : []
            textView.textContainer?.size = wrapCode
                ? NSSize(width: scrollView.contentView.bounds.width,
                         height: CGFloat.greatestFiniteMagnitude)
                : NSSize(width: CGFloat.greatestFiniteMagnitude,
                         height: CGFloat.greatestFiniteMagnitude)
            textView.layoutManager?.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: textView.string.utf16.count),
                actualCharacterRange: nil
            )
        }

        // Sync font size.
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes = [.foregroundColor: NSColor.labelColor, .font: font]
        }

        let coord = context.coordinator
        coord.onCodeChange = onCodeChange
        coord.onCursorFirstLine = onCursorFirstLine

        if textView.isEditable != isEditing {
            textView.isEditable = isEditing
            textView.isSelectable = isEditing
            textView.window?.invalidateCursorRects(for: textView)
        }

        let wasCodeFocused = coord.wasCodeFocused
        coord.wasCodeFocused = focusCode

        // Focus / unfocus the NSTextView.
        if focusCode && isEditing && textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                coord.onCursorFirstLine?(true)
            }
        } else if !focusCode && wasCodeFocused && isEditing {
            if textView.window?.firstResponder === textView {
                textView.window?.makeFirstResponder(nil)
            }
        }

        let justStoppedEditing = coord.wasEditing && !isEditing
        coord.wasEditing = isEditing

        if justStoppedEditing && textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }

        if isEditing {
            if textView.string != code {
                textView.string = code
                textView.textColor = .labelColor
            }
        } else if justStoppedEditing || textView.string != code || coord.renderedTheme != theme {
            if let highlighted = Self.highlightr?.highlight(code, as: language) {
                let result = NSMutableAttributedString(attributedString: highlighted)
                let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                result.addAttribute(.font, value: font,
                                    range: NSRange(location: 0, length: result.length))
                textView.textStorage?.setAttributedString(result)
                coord.renderedTheme = theme
            } else {
                textView.string = code
                textView.textColor = .labelColor
                coord.renderedTheme = theme
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onCodeChange: ((String) -> Void)?
        var onCursorFirstLine: ((Bool) -> Void)?
        var wasEditing: Bool = false
        var wasCodeFocused: Bool = false
        var renderedTheme: String = ""

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onCodeChange?(tv.string)
            reportFirstLine(tv)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            reportFirstLine(tv)
        }

        private func reportFirstLine(_ tv: NSTextView) {
            // Visual first line, not logical: when wrap is on, a long line
            // wraps to multiple display lines and we need to know which one
            // the cursor sits on.
            guard let lm = tv.layoutManager, let tc = tv.textContainer else {
                onCursorFirstLine?(true)
                return
            }
            lm.ensureLayout(for: tc)
            let totalGlyphs = lm.numberOfGlyphs
            guard totalGlyphs > 0 else {
                onCursorFirstLine?(true)
                return
            }
            let cursorPos = tv.selectedRange().location
            var glyphIdx = lm.glyphIndexForCharacter(at: cursorPos)
            if glyphIdx >= totalGlyphs { glyphIdx = totalGlyphs - 1 }
            var lineGlyphRange = NSRange()
            _ = lm.lineFragmentRect(forGlyphAt: glyphIdx,
                                    effectiveRange: &lineGlyphRange)
            onCursorFirstLine?(lineGlyphRange.location == 0)
        }
    }
}

private final class PointerCursorTextView: NSTextView {
    override func resetCursorRects() {
        if isEditable {
            super.resetCursorRects()
        } else {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isEditable {
            super.cursorUpdate(with: event)
        } else {
            NSCursor.pointingHand.set()
        }
    }
}
