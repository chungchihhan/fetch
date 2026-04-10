import SwiftUI
import AppKit

// Reference-type state so mutations from the key handler always propagate
@Observable
private final class ListNavState {
    var focusedTab: Int = 0      // which tab the selection belongs to
    var focusedIndex: Int? = nil
    var editStep: Int = 0        // 0=browse, 1=title edit, 2=code edit
    var cursorOnFirstLine: Bool = true
    var isEditing: Bool { editStep > 0 }

    func setFocus(_ index: Int?, tab: Int) {
        focusedTab = tab
        focusedIndex = index
    }
}

struct SnippetListView: View {
    @Environment(SnippetStore.self) var store
    @State private var nav = ListNavState()

    var snippets: [Snippet] { store.tabs[store.activeTab] }

    var body: some View {
        let handler = makeKeyHandler(nav: nav, store: store)

        ZStack {
            // Zero-size background view that installs the key monitor
            KeyMonitorView(onKey: handler)
                .frame(width: 0, height: 0)

            // Content stays in normal SwiftUI hierarchy for proper @Observable tracking
            if snippets.isEmpty {
                Text("Press ⌘N to add a snippet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { i, _ in
                                SnippetRowView(
                                    snippet: binding(for: i),
                                    isFocused: nav.focusedTab == store.activeTab && nav.focusedIndex == i,
                                    editStep: nav.focusedTab == store.activeTab && nav.focusedIndex == i ? nav.editStep : 0,
                                    onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
                                    onCodeChange: { store.tabs[store.activeTab][i].code = $0 },
                                    onCursorFirstLine: { nav.cursorOnFirstLine = $0 }
                                )
                                .id(i)
                                .onTapGesture {
                                    nav.setFocus(i, tab: store.activeTab)
                                    guard nav.editStep == 0 else { return }
                                    let snippets = store.tabs[store.activeTab]
                                    guard i < snippets.count else { return }
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                                    postToast("Copied")
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: nav.focusedIndex) { _, idx in
                        if let idx { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }
        }
        .onChange(of: store.activeTab) { _, newTab in
            nav.editStep = 0
            nav.cursorOnFirstLine = true
            let tabSnippets = store.tabs[newTab]
            nav.setFocus(tabSnippets.isEmpty ? nil : 0, tab: newTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
            let tab = store.activeTab
            if nav.focusedIndex == nil, !snippets.isEmpty {
                nav.setFocus(0, tab: tab)
            }
        }
    }

    private func binding(for index: Int) -> Binding<Snippet> {
        Binding(
            get: {
                let tab = store.activeTab
                guard index < store.tabs[tab].count else { return Snippet(title: "", code: "") }
                return store.tabs[tab][index]
            },
            set: {
                let tab = store.activeTab
                guard index < store.tabs[tab].count else { return }
                store.tabs[tab][index] = $0
            }
        )
    }

    private func makeKeyHandler(nav: ListNavState, store: SnippetStore) -> (NSEvent) -> Bool {
        { event in
            let snippets = store.tabs[store.activeTab]
            let tab = store.activeTab
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)


            func enterEdit() {
                if nav.focusedIndex == nil, !snippets.isEmpty { nav.setFocus(0, tab: tab) }
                guard nav.focusedIndex != nil else { return }
                nav.editStep = 1
                NotificationCenter.default.post(name: .editModeChanged, object: true)
            }

            func exitEdit(copy: Bool) {
                if copy, let i = nav.focusedIndex, i < snippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                    postToast("Copied")
                } else {
                    postToast("Saved")
                }
                nav.editStep = 0
                store.save(tab: tab)
                NotificationCenter.default.post(name: .editModeChanged, object: false)
            }

            // ─── Edit mode ───────────────────────────────────────────────────
            if nav.editStep > 0 {
                switch event.keyCode {

                case 14 where flags == .command:    // ⌘E — save and exit
                    exitEdit(copy: false); return true

                case 36:                            // Enter / Shift+Enter
                    if nav.editStep == 2 && flags.contains(.shift) {
                        return false                // Shift+Enter in code → newline (pass through)
                    }
                    exitEdit(copy: false)           // Enter → save + exit (no copy)
                    return true

                case 53:                            // Esc — save and exit (no copy)
                    exitEdit(copy: false); return true

                case 48:                            // Tab / Shift+Tab — navigate fields
                    if flags.contains(.shift) {
                        if nav.editStep == 2 { nav.editStep = 1 }   // code → title
                    } else {
                        if nav.editStep == 1 { nav.editStep = 2 }   // title → code
                    }
                    return true

                case 125:                           // ↓
                    if nav.editStep == 1 { nav.editStep = 2; return true } // title → code
                    return false                    // in code: pass through (NSTextView navigates)

                case 126:                           // ↑
                    if nav.editStep == 1 { return true }          // in title: do nothing
                    if nav.editStep == 2 && nav.cursorOnFirstLine { // in code first line → title
                        nav.editStep = 1; return true
                    }
                    return false                    // in code: pass through

                default:
                    return false                    // let typing reach text fields
                }
            }

            // ─── Browse mode ─────────────────────────────────────────────────
            switch event.keyCode {

            case 36:                                // Enter — copy focused snippet code
                if let i = nav.focusedIndex, i < snippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                    postToast("Copied")
                }
                return true

            case 14 where flags == .command:        // ⌘E — enter edit mode
                enterEdit(); return true

            case 125:                               // ↓ — next snippet
                if !snippets.isEmpty {
                    let current = nav.focusedIndex ?? -1
                    nav.setFocus(max(0, min(snippets.count - 1, current + 1)), tab: tab)
                }
                return true

            case 126:                               // ↑ — prev snippet
                if !snippets.isEmpty {
                    let current = nav.focusedIndex ?? snippets.count
                    nav.setFocus(max(0, min(snippets.count - 1, current - 1)), tab: tab)
                }
                return true

            case 53:                               // Esc — close popover
                NotificationCenter.default.post(name: NSPopover.willCloseNotification, object: nil)
                NSApp.hide(nil)
                return true

            case 8 where flags.contains(.command): // ⌘C — copy code
                if let i = nav.focusedIndex, i < snippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                    postToast("Copied")
                }
                return true

            case 45 where flags.contains(.command): // ⌘N — new snippet
                store.addSnippet()
                nav.setFocus(store.tabs[tab].count - 1, tab: tab)
                enterEdit()
                return true

            case 2 where flags.contains(.command): // ⌘D — delete
                if let i = nav.focusedIndex, i < snippets.count {
                    store.deleteSnippet(id: snippets[i].id, tab: tab)
                    let remaining = store.tabs[tab]
                    nav.setFocus(remaining.isEmpty ? nil : max(0, i - 1), tab: tab)
                    postToast("Deleted")
                }
                return true

            default:
                return false
            }
        }
    }
}

// Zero-size NSViewRepresentable — only installs a local key monitor
struct KeyMonitorView: NSViewRepresentable {
    let onKey: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let v = KeyCatchingNSView()
        v.onKey = onKey
        return v
    }

    func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
        nsView.onKey = onKey
    }
}

final class KeyCatchingNSView: NSView {
    var onKey: ((NSEvent) -> Bool)?
    private var localMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        guard window != nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.onKey?(event) == true ? nil : event
        }
    }

    deinit {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}

// Notification names used across SnippetListView, AppDelegate, and PopoverContentView
extension Notification.Name {
    static let editModeChanged = Notification.Name("JotKitEditModeChanged")
    static let popoverDidOpen  = Notification.Name("JotKitPopoverDidOpen")
    static let toastMessage    = Notification.Name("JotKitToastMessage")
}

private func postToast(_ message: String) {
    NotificationCenter.default.post(name: .toastMessage, object: message)
}
