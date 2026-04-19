import SwiftUI
import AppKit

// View-local nav state. Edit mode and focus index live on SnippetStore so
// they sync across the popover and the main window.
@Observable
private final class ListNavState {
    var cursorOnFirstLine: Bool = true
}

struct SnippetListView: View {
    @Environment(SnippetStore.self) var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var nav = ListNavState()
    @State private var dropTargetIndex: Int? = nil

    var snippets: [Snippet] { store.tabs[store.activeTab] }

    var body: some View {
        let handler = makeKeyHandler(nav: nav, store: store)

        ZStack {
            // Zero-size background view that installs the key monitor
            KeyMonitorView(
                onKey: handler,
                onWindowResignKey: {
                    guard store.editStep > 0 else { return }
                    let tab = store.activeTab
                    let currentSnippets = store.tabs[tab]
                    if let snapshot = store.editSnapshot,
                       let i = store.focusedIndex, i < currentSnippets.count,
                       currentSnippets[i] != snapshot {
                        store.undoManager.registerUndo(withTarget: store) { [snapshot, tab] s in
                            s.replaceSnippet(id: snapshot.id, with: snapshot, tab: tab)
                        }
                        store.undoManager.setActionName("Edit Snippet")
                    }
                    store.editSnapshot = nil
                    store.editStep = 0
                    store.save(tab: tab)
                    NotificationCenter.default.post(name: .editModeChanged, object: false)
                }
            )
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
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { i, snippet in
                                SnippetRowView(
                                    snippet: binding(for: i),
                                    isFocused: store.focusedIndex == i,
                                    editStep: store.focusedIndex == i ? store.editStep : 0,
                                    onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
                                    onCodeChange: { store.tabs[store.activeTab][i].code = $0 },
                                    onCursorFirstLine: { nav.cursorOnFirstLine = $0 }
                                )
                                .id(i)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(Color.styleAccent(colorScheme, style: iconStyle))
                                        .frame(height: 2)
                                        .offset(y: -6)
                                        .opacity(dropTargetIndex == i ? 1 : 0)
                                }
                                .onTapGesture {
                                    store.focusedIndex = i
                                    guard store.editStep == 0 else { return }
                                    let snippets = store.tabs[store.activeTab]
                                    guard i < snippets.count else { return }
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                                    postToast("Copied")
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    dropTargetIndex = nil
                                    guard let src = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                    guard let newIndex = store.moveSnippet(id: src, toOffset: i, tab: store.activeTab) else { return false }
                                    store.focusedIndex = newIndex
                                    return true
                                } isTargeted: { targeted in
                                    if targeted { dropTargetIndex = i }
                                    else if dropTargetIndex == i { dropTargetIndex = nil }
                                }
                            }

                            // Drop here to move the dragged snippet to the end.
                            Color.clear
                                .frame(height: 24)
                                .contentShape(Rectangle())
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(Color.styleAccent(colorScheme, style: iconStyle))
                                        .frame(height: 2)
                                        .opacity(dropTargetIndex == snippets.count ? 1 : 0)
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    dropTargetIndex = nil
                                    guard let src = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                    guard let newIndex = store.moveSnippet(id: src, toOffset: snippets.count, tab: store.activeTab) else { return false }
                                    store.focusedIndex = newIndex
                                    return true
                                } isTargeted: { targeted in
                                    if targeted { dropTargetIndex = snippets.count }
                                    else if dropTargetIndex == snippets.count { dropTargetIndex = nil }
                                }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 10)
                    }
                    .onChange(of: store.focusedIndex) { _, idx in
                        if let idx { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }
        }
        .onChange(of: store.activeTab) { _, newTab in
            store.editStep = 0
            nav.cursorOnFirstLine = true
            let tabSnippets = store.tabs[newTab]
            store.focusedIndex = tabSnippets.isEmpty ? nil : 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
            if store.focusedIndex == nil, !snippets.isEmpty {
                store.focusedIndex = 0
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

            // ⌘= / ⌘- — adjust snippet font size globally (works in any mode).
            if flags.contains(.command), event.keyCode == 24 || event.keyCode == 27 {
                adjustFontSize(delta: event.keyCode == 24 ? 1 : -1)
                return true
            }


            func enterEdit() {
                if store.focusedIndex == nil, !snippets.isEmpty { store.focusedIndex = 0 }
                guard let i = store.focusedIndex, i < snippets.count else { return }
                store.editSnapshot = snippets[i]
                store.editStep = 1
                NotificationCenter.default.post(name: .editModeChanged, object: true)
            }

            func exitEdit(copy: Bool) {
                let currentSnippets = store.tabs[store.activeTab]
                if copy, let i = store.focusedIndex, i < currentSnippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentSnippets[i].code, forType: .string)
                    postToast("Copied")
                } else {
                    postToast("Saved")
                }
                // If the content changed during the edit, register a single undo entry
                // that captures the whole edit session.
                if let snapshot = store.editSnapshot,
                   let i = store.focusedIndex, i < currentSnippets.count,
                   currentSnippets[i] != snapshot {
                    store.undoManager.registerUndo(withTarget: store) { [snapshot, tab] s in
                        s.replaceSnippet(id: snapshot.id, with: snapshot, tab: tab)
                    }
                    store.undoManager.setActionName("Edit Snippet")
                }
                store.editSnapshot = nil
                store.editStep = 0
                store.save(tab: tab)
                NotificationCenter.default.post(name: .editModeChanged, object: false)
            }

            // ─── Edit mode ───────────────────────────────────────────────────
            if store.editStep > 0 {
                switch event.keyCode {

                case 14 where flags == .command:    // ⌘E — save and exit
                    exitEdit(copy: false); return true

                case 36:                            // Enter / Shift+Enter
                    if store.editStep == 2 && flags.contains(.shift) {
                        return false                // Shift+Enter in code → newline (pass through)
                    }
                    exitEdit(copy: false)           // Enter → save + exit (no copy)
                    return true

                case 53:                            // Esc — save and exit (no copy)
                    exitEdit(copy: false); return true

                case 48:                            // Tab / Shift+Tab — navigate fields
                    if flags.contains(.shift) {
                        if store.editStep == 2 { store.editStep = 1 }   // code → title
                    } else {
                        if store.editStep == 1 { store.editStep = 2 }   // title → code
                    }
                    return true

                case 125:                           // ↓
                    if store.editStep == 1 { store.editStep = 2; return true } // title → code
                    return false                    // in code: pass through (NSTextView navigates)

                case 126:                           // ↑
                    if store.editStep == 1 { return true }          // in title: do nothing
                    if store.editStep == 2 && nav.cursorOnFirstLine { // in code first line → title
                        store.editStep = 1; return true
                    }
                    return false                    // in code: pass through

                default:
                    return false                    // let typing reach text fields
                }
            }

            // ─── Browse mode ─────────────────────────────────────────────────
            switch event.keyCode {

            case 6 where flags == .command:         // ⌘Z — undo
                store.undoManager.undo()
                return true

            case 6 where flags == [.command, .shift]: // ⌘⇧Z — redo
                store.undoManager.redo()
                return true

            case 36:                                // Enter — copy focused snippet code
                if let i = store.focusedIndex, i < snippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                    postToast("Copied")
                }
                return true

            case 14 where flags == .command:        // ⌘E — enter edit mode
                enterEdit(); return true

            case 125 where flags.contains(.option): // ⌥↓ — move focused snippet down
                if let i = store.focusedIndex, i < snippets.count - 1,
                   let newIndex = store.moveSnippet(from: i, toOffset: i + 2, tab: tab) {
                    store.focusedIndex = newIndex
                }
                return true

            case 126 where flags.contains(.option): // ⌥↑ — move focused snippet up
                if let i = store.focusedIndex, i > 0,
                   let newIndex = store.moveSnippet(from: i, toOffset: i - 1, tab: tab) {
                    store.focusedIndex = newIndex
                }
                return true

            case 125:                               // ↓ — next snippet
                if !snippets.isEmpty {
                    let current = store.focusedIndex ?? -1
                    store.focusedIndex = max(0, min(snippets.count - 1, current + 1))
                }
                return true

            case 126:                               // ↑ — prev snippet
                if !snippets.isEmpty {
                    let current = store.focusedIndex ?? snippets.count
                    store.focusedIndex = max(0, min(snippets.count - 1, current - 1))
                }
                return true

            case 53:                               // Esc — close popover (main window ignores)
                NotificationCenter.default.post(name: .closePopover, object: nil)
                return true

            case 8 where flags.contains(.command): // ⌘C — copy title + code
                if let i = store.focusedIndex, i < snippets.count {
                    let s = snippets[i]
                    let formatted = "# \(s.title)\n\(s.code)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formatted, forType: .string)
                    postToast("Copied")
                }
                return true

            case 45 where flags.contains(.command): // ⌘N — new snippet
                store.addSnippet()
                store.focusedIndex = store.tabs[tab].count - 1
                enterEdit()
                return true

            case 2 where flags.contains(.command): // ⌘D — delete
                if let i = store.focusedIndex, i < snippets.count {
                    store.deleteSnippet(id: snippets[i].id, tab: tab)
                    let remaining = store.tabs[tab]
                    store.focusedIndex = remaining.isEmpty ? nil : max(0, i - 1)
                    postToast("Deleted")
                }
                return true

            case 43 where flags.contains(.command): // ⌘, — open settings
                NotificationCenter.default.post(name: .openSettings, object: nil)
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
    var onWindowResignKey: (() -> Void)? = nil

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let v = KeyCatchingNSView()
        v.onKey = onKey
        v.onWindowResignKey = onWindowResignKey
        return v
    }

    func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
        nsView.onKey = onKey
        nsView.onWindowResignKey = onWindowResignKey
    }
}

final class KeyCatchingNSView: NSView {
    var onKey: ((NSEvent) -> Bool)?
    var onWindowResignKey: (() -> Void)?
    private var localMonitor: Any?
    private var resignObserver: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let o = resignObserver { NotificationCenter.default.removeObserver(o); resignObserver = nil }
        guard let window else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle events targeted at our own window. Without this filter,
            // every instance of this view (popover + main window) would intercept
            // every key press in the app, causing double-mutations and cross-fire.
            guard let self, let selfWindow = self.window,
                  event.window === selfWindow else { return event }
            return self.onKey?(event) == true ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWindowResignKey?()
        }
    }

    deinit {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        if let o = resignObserver { NotificationCenter.default.removeObserver(o) }
    }
}

// Notification names used across SnippetListView, AppDelegate, and PopoverContentView
extension Notification.Name {
    static let editModeChanged = Notification.Name("FetchEditModeChanged")
    static let popoverDidOpen  = Notification.Name("FetchPopoverDidOpen")
    static let toastMessage    = Notification.Name("FetchToastMessage")
    static let openSettings    = Notification.Name("FetchOpenSettings")
    static let shortcutChanged = Notification.Name("FetchShortcutChanged")
}

private func postToast(_ message: String) {
    NotificationCenter.default.post(name: .toastMessage, object: message)
}

private func adjustFontSize(delta: Double) {
    let d = UserDefaults.standard
    let curCode = (d.object(forKey: "fetchFontSize") as? Double) ?? 11
    let curTitle = (d.object(forKey: "fetchTitleFontSize") as? Double) ?? 11
    let curTab = (d.object(forKey: "fetchTabFontSize") as? Double) ?? 10
    d.set(max(8, min(20, curCode + delta)), forKey: "fetchFontSize")
    d.set(max(8, min(20, curTitle + delta)), forKey: "fetchTitleFontSize")
    d.set(max(8, min(20, curTab + delta)), forKey: "fetchTabFontSize")
}
