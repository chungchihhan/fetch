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
        h?.setTheme(to: "atom-one-dark")
        return h
    }()

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
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
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
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

        if isEditing {
            if textView.string != code { textView.string = code }
        } else if justStoppedEditing || textView.string != code {
            if let highlighted = Self.highlightr?.highlight(code, as: language) {
                textView.textStorage?.setAttributedString(highlighted)
            } else {
                textView.string = code
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
