import SwiftUI
import Highlightr

struct HighlightedCodeView: NSViewRepresentable {
    var code: String
    var language: String
    var isEditing: Bool
    var onCodeChange: ((String) -> Void)?

    private let highlightr: Highlightr = {
        let h = Highlightr()!
        h.setTheme(to: "atom-one-dark")
        return h
    }()

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isRichText = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.isEditable = isEditing

        // Only re-highlight if code changed to avoid cursor jump during editing
        if textView.string != code {
            if let highlighted = highlightr.highlight(code, as: language) {
                textView.textStorage?.setAttributedString(highlighted)
            } else {
                textView.string = code
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeChange: onCodeChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onCodeChange: ((String) -> Void)?
        init(onCodeChange: ((String) -> Void)?) { self.onCodeChange = onCodeChange }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onCodeChange?(tv.string)
        }
    }
}
