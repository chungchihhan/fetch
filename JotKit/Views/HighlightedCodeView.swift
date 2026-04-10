import SwiftUI
import Highlightr

struct HighlightedCodeView: NSViewRepresentable {
    var code: String
    var language: String
    var isEditing: Bool
    var focusCode: Bool = false
    var onCodeChange: ((String) -> Void)?
    var onCursorFirstLine: ((Bool) -> Void)?

    private static let highlightr: Highlightr? = {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-light")
        return h
    }()

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.isRichText = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.font = font
        textView.textColor = .black
        textView.insertionPointColor = .black
        textView.typingAttributes = [
            .foregroundColor: NSColor.black,
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
        let coord = context.coordinator
        coord.onCodeChange = onCodeChange
        textView.isEditable = isEditing

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
                textView.textColor = .black
            }
        } else if justStoppedEditing || textView.string != code {
            if let highlighted = Self.highlightr?.highlight(code, as: language) {
                // Keep syntax colors but force our font so edit/browse look identical
                let result = NSMutableAttributedString(attributedString: highlighted)
                let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                result.addAttribute(.font, value: font,
                                    range: NSRange(location: 0, length: result.length))
                textView.textStorage?.setAttributedString(result)
            } else {
                textView.string = code
                textView.textColor = .black
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onCodeChange: ((String) -> Void)?
        var onCursorFirstLine: ((Bool) -> Void)?
        var wasEditing: Bool = false
        var wasCodeFocused: Bool = false

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
