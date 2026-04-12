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
    var onHeightChange: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private static let highlightr: Highlightr? = Highlightr()
    private static var currentTheme: String = ""

    private var theme: String { colorScheme == .dark ? "atom-one-dark" : "atom-one-light" }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PointerCursorTextView()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isRichText = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]
        textView.delegate = context.coordinator

        // No line-wrapping
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

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync highlight theme with current appearance (shared Highlightr singleton)
        if Self.currentTheme != theme {
            Self.highlightr?.setTheme(to: theme)
            Self.currentTheme = theme
        }

        // Sync wrap mode
        let currentlyWrapping = textView.textContainer?.widthTracksTextView ?? false
        if currentlyWrapping != wrapCode {
            textView.textContainer?.widthTracksTextView = wrapCode
            textView.isHorizontallyResizable = !wrapCode
            textView.autoresizingMask = wrapCode ? [.width] : []
            if wrapCode {
                let clipWidth = scrollView.contentView.bounds.width
                let w = clipWidth > 0 ? clipWidth : 300
                textView.frame.size.width = w
                textView.textContainer?.size = NSSize(width: w,
                                                      height: CGFloat.greatestFiniteMagnitude)
            } else {
                textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                      height: CGFloat.greatestFiniteMagnitude)
            }
            textView.layoutManager?.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: textView.string.utf16.count),
                actualCharacterRange: nil
            )
        }

        // Sync font size
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes = [.foregroundColor: NSColor.labelColor, .font: font]
        }

        let coord = context.coordinator
        coord.onCodeChange = onCodeChange
        coord.onHeightChange = onHeightChange
        if textView.isEditable != isEditing {
            textView.isEditable = isEditing
            textView.isSelectable = isEditing
            textView.window?.invalidateCursorRects(for: textView)
        }

        let wasCodeFocused = coord.wasCodeFocused
        coord.wasCodeFocused = focusCode

        // Update cursor-first-line callback reference
        coord.onCursorFirstLine = onCursorFirstLine

        // Focus / unfocus the NSTextView
        if focusCode && isEditing && textView.window?.firstResponder !== textView {
            // Defer to next run loop so the view is fully laid out before requesting focus
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

        // Release AppKit first responder when exiting edit mode entirely so
        // SwiftUI's @FocusState can work correctly on the next edit entry.
        if justStoppedEditing && textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }

        if isEditing {
            if textView.string != code {
                textView.string = code
                // Restore white — setting .string strips all attributes
                textView.textColor = .labelColor
            }
        } else if justStoppedEditing || textView.string != code || coord.renderedTheme != theme {
            if let highlighted = Self.highlightr?.highlight(code, as: language) {
                // Keep syntax colors but force our font so edit/browse look identical
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

        // Report natural height when wrapping so the parent can expand the frame
        if wrapCode && !isEditing {
            let onH = coord.onHeightChange
            DispatchQueue.main.async {
                guard let lm = textView.layoutManager,
                      let tc = textView.textContainer else { return }
                lm.ensureLayout(for: tc)
                let used = lm.usedRect(for: tc)
                let h = used.height + textView.textContainerInset.height * 2
                onH?(max(16, h))
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
        var onHeightChange: ((CGFloat) -> Void)?

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
            let cursorPos = tv.selectedRange().location
            let isFirst = !tv.string.prefix(cursorPos).contains("\n")
            onCursorFirstLine?(isFirst)
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
