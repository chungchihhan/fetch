import SwiftUI
import AppKit

// View-local nav state. Edit mode and focus index live on SnippetStore so
// they sync across the popover and the main window.
@Observable
private final class ListNavState {
    var cursorOnFirstLine: Bool = true
    var showTabSwitcher: Bool = false
    var cmdHoldTask: Task<Void, Never>? = nil

    // Language picker overlay state.
    var showLanguagePicker: Bool = false
    var langSearch: String = ""
    var langSearchActive: Bool = false   // true once `/` (or a letter) starts a search
    var langSelectedIndex: Int = 0       // index into the filtered right-column list
    var starredLanguages: [String] = loadStarredLanguages()  // user quick picks (excludes "auto")
}

// Quick-pick languages shown in the picker's left column, selectable by
// pressing 1–9. Star-toggled from the right column and persisted. "auto" is
// always pinned first and is not stored in this list.
private let defaultStarredLanguages = ["bash", HighlightedCodeView.plainLanguage]
// Bumped so updating to this version resets the quick picks to the new
// default (auto + bash + plaintext) rather than keeping the old long list.
private let starredDefaultsKey = "fetchStarredLanguagesV2"

private func loadStarredLanguages() -> [String] {
    UserDefaults.standard.stringArray(forKey: starredDefaultsKey) ?? defaultStarredLanguages
}

// Full left-column list: "auto" pinned first, then the user's starred picks.
private func quickPicks(_ starred: [String]) -> [String] {
    [HighlightedCodeView.autoLanguage] + starred
}

// All languages matching the search (case-insensitive substring). Empty search
// returns the full list. Shared by the key handler and the overlay so the
// highlighted row and what Enter selects always agree.
private func filteredLanguages(_ search: String) -> [String] {
    let all = HighlightedCodeView.supportedLanguages
    let query = search.trimmingCharacters(in: .whitespaces).lowercased()
    guard !query.isEmpty else { return all }
    return all.filter { $0.contains(query) }
}

struct SnippetListView: View {
    @Environment(SnippetStore.self) var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var nav = ListNavState()
    @State private var dropTargetIndex: Int? = nil
    @State private var copyFlashIndex: Int? = nil

    var snippets: [Snippet] { store.tabs[store.activeTab] }

    var body: some View {
        let handler = makeKeyHandler(nav: nav, store: store, onCopyFlash: triggerCopyFlash)

        ZStack {
            // Zero-size background view that installs the key monitor
            KeyMonitorView(
                onKey: handler,
                onWindowResignKey: {
                    nav.cmdHoldTask?.cancel()
                    nav.cmdHoldTask = nil
                    nav.showTabSwitcher = false
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
                },
                onFlagsChanged: { event in
                    let cmdDown = event.modifierFlags.contains(.command)
                    if cmdDown {
                        guard nav.cmdHoldTask == nil, !nav.showTabSwitcher else { return }
                        nav.cmdHoldTask = Task { @MainActor in
                            do {
                                try await Task.sleep(for: .seconds(0.3))
                            } catch {
                                return
                            }
                            nav.showTabSwitcher = true
                            nav.cmdHoldTask = nil
                        }
                    } else {
                        nav.cmdHoldTask?.cancel()
                        nav.cmdHoldTask = nil
                        nav.showTabSwitcher = false
                    }
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
                                snippetRow(at: i, nav: nav)
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

            if let idx = store.pendingDeleteIndex, idx < snippets.count {
                DeleteConfirmOverlay(
                    title: snippets[idx].title,
                    onConfirm: {
                        performDelete(at: idx, store: store, tab: store.activeTab)
                        store.pendingDeleteIndex = nil
                    },
                    onCancel: { store.pendingDeleteIndex = nil }
                )
            }

            if nav.showTabSwitcher {
                TabSwitcherOverlay(
                    tabNames: store.tabNames,
                    activeTab: store.activeTab
                )
            }

            if nav.showLanguagePicker, let i = store.focusedIndex, i < snippets.count {
                LanguagePickerOverlay(
                    current: snippets[i].language,
                    search: nav.langSearch,
                    searchActive: nav.langSearchActive,
                    selectedIndex: nav.langSelectedIndex,
                    starred: nav.starredLanguages,
                    onSelect: { setLanguage($0, at: i, nav: nav) },
                    onToggleStar: { toggleStar($0, nav: nav) },
                    onClose: { nav.showLanguagePicker = false }
                )
            }
        }
        .animation(.easeInOut(duration: 0.12), value: nav.showTabSwitcher)
        .animation(.easeInOut(duration: 0.12), value: nav.showLanguagePicker)
        .onChange(of: store.activeTab) { _, newTab in
            store.editStep = 0
            store.pendingDeleteIndex = nil
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

    private func focusAndCopy(at i: Int) {
        store.focusedIndex = i
        let snippets = store.tabs[store.activeTab]
        guard i < snippets.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippets[i].code, forType: .string)
        postToast("Copied")
        triggerCopyFlash(at: i)
    }

    private func triggerCopyFlash(at i: Int) {
        copyFlashIndex = i
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { copyFlashIndex = nil }
    }

    private func focusAndEnterEdit(at i: Int, step: Int, cursor: Int?) {
        store.focusedIndex = i
        guard store.editStep == 0 else { return }
        let current = store.tabs[store.activeTab]
        guard i < current.count else { return }
        store.editSnapshot = current[i]
        store.pendingCursorIndex = cursor
        store.editStep = step
        NotificationCenter.default.post(name: .editModeChanged, object: true)
    }

    private func openLanguagePicker(at i: Int, nav: ListNavState) {
        guard store.editStep == 0 else { return }
        let snippets = store.tabs[store.activeTab]
        guard i < snippets.count else { return }
        store.focusedIndex = i
        nav.langSearch = ""
        nav.langSearchActive = false
        nav.langSelectedIndex = max(0, filteredLanguages("").firstIndex(of: snippets[i].language) ?? 0)
        nav.showLanguagePicker = true
    }

    private func toggleStar(_ lang: String, nav: ListNavState) {
        guard lang != HighlightedCodeView.autoLanguage else { return }
        if let idx = nav.starredLanguages.firstIndex(of: lang) {
            nav.starredLanguages.remove(at: idx)
        } else {
            nav.starredLanguages.append(lang)
        }
        UserDefaults.standard.set(nav.starredLanguages, forKey: starredDefaultsKey)
    }

    private func setLanguage(_ lang: String, at i: Int, nav: ListNavState) {
        let tab = store.activeTab
        guard i < store.tabs[tab].count else { return }
        store.tabs[tab][i].language = lang
        store.save(tab: tab)
        nav.showLanguagePicker = false
        postToast(lang == HighlightedCodeView.autoLanguage ? "Language: auto-detect" : "Language: \(lang)")
    }

    @ViewBuilder
    private func snippetRow(at i: Int, nav: ListNavState) -> some View {
        let rowFocused: Bool = store.focusedIndex == i
        let rowEditStep: Int = rowFocused ? store.editStep : 0
        let isFlashing: Bool = copyFlashIndex.map { $0 == i } ?? false
        SnippetRowView(
            snippet: binding(for: i),
            isFocused: rowFocused,
            editStep: rowEditStep,
            onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
            onCodeChange: { store.tabs[store.activeTab][i].code = $0 },
            onOpenLanguagePicker: { openLanguagePicker(at: i, nav: nav) },
            onCursorFirstLine: { isFirst in
                nav.cursorOnFirstLine = isFirst
                if store.editStep == 1 { store.editStep = 2 }
            },
            onEnterEdit: { focusAndEnterEdit(at: i, step: 1, cursor: nil) },
            onEnterEditAtTitle: { idx in focusAndEnterEdit(at: i, step: 1, cursor: idx) },
            onEnterEditAtCode: { idx in focusAndEnterEdit(at: i, step: 2, cursor: idx) },
            onCopy: { focusAndCopy(at: i) },
            onTitleBeganEditing: {
                if store.editStep == 2 {
                    store.pendingCursorIndex = nil
                    store.editStep = 1
                }
            },
            cursorTargetIndex: rowFocused ? store.pendingCursorIndex : nil,
            onCursorTargetConsumed: { store.pendingCursorIndex = nil },
            isCopying: isFlashing
        )
        .id(i)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.styleAccent(colorScheme, style: iconStyle))
                .frame(height: 2)
                .offset(y: -6)
                .opacity(dropTargetIndex == i ? 1 : 0)
        }
        .onTapGesture { focusAndEnterEdit(at: i, step: 1, cursor: nil) }
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

    private func makeKeyHandler(nav: ListNavState, store: SnippetStore, onCopyFlash: @escaping (Int) -> Void) -> (NSEvent) -> Bool {
        { event in
            let snippets = store.tabs[store.activeTab]
            let tab = store.activeTab
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cancel any pending cmd-hold when any key fires (e.g. normal ⌘1 tab switch).
            nav.cmdHoldTask?.cancel()
            nav.cmdHoldTask = nil

            // ─── Tab switcher overlay ────────────────────────────────────────────────
            if nav.showTabSwitcher {
                switch event.keyCode {
                case 18: store.activeTab = 0; nav.showTabSwitcher = false; return true  // 1
                case 19: store.activeTab = 1; nav.showTabSwitcher = false; return true  // 2
                case 20: store.activeTab = 2; nav.showTabSwitcher = false; return true  // 3
                case 21: store.activeTab = 3; nav.showTabSwitcher = false; return true  // 4
                case 23: store.activeTab = 4; nav.showTabSwitcher = false; return true  // 5
                case 22: store.activeTab = 5; nav.showTabSwitcher = false; return true  // 6
                case 53: nav.showTabSwitcher = false; return true                       // Esc
                default: return true  // swallow all other keys while switcher is visible
                }
            }

            // ─── Language picker overlay ─────────────────────────────────────
            if nav.showLanguagePicker {
                guard let i = store.focusedIndex, i < snippets.count else {
                    nav.showLanguagePicker = false
                    return true
                }
                let filtered = filteredLanguages(nav.langSearch)
                let chars = event.charactersIgnoringModifiers ?? ""

                switch event.keyCode {
                case 53:  // Esc — leave search first, then close
                    if nav.langSearchActive {
                        nav.langSearchActive = false
                        nav.langSearch = ""
                        nav.langSelectedIndex = 0
                    } else {
                        nav.showLanguagePicker = false
                    }
                    return true
                case 36:  // Enter — select highlighted
                    if nav.langSelectedIndex < filtered.count {
                        setLanguage(filtered[nav.langSelectedIndex], at: i, nav: nav)
                    }
                    return true
                case 125: // ↓
                    if !filtered.isEmpty {
                        nav.langSelectedIndex = min(filtered.count - 1, nav.langSelectedIndex + 1)
                    }
                    return true
                case 126: // ↑
                    if !filtered.isEmpty {
                        nav.langSelectedIndex = max(0, nav.langSelectedIndex - 1)
                    }
                    return true
                case 51:  // Delete — edit search text
                    if nav.langSearchActive, !nav.langSearch.isEmpty {
                        nav.langSearch.removeLast()
                        nav.langSelectedIndex = 0
                    }
                    return true
                default:
                    break
                }

                // Don't consume modifier combos for typed input.
                if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
                    return true
                }

                if !nav.langSearchActive {
                    // 1–9 select a quick-pick language from the left column.
                    let quick = quickPicks(nav.starredLanguages)
                    if chars.count == 1, let n = Int(chars), (1...min(9, quick.count)).contains(n) {
                        setLanguage(quick[n - 1], at: i, nav: nav)
                        return true
                    }
                    // `/` opens search; any other letter opens search with that letter.
                    if chars == "/" {
                        nav.langSearchActive = true
                        nav.langSearch = ""
                        nav.langSelectedIndex = 0
                    } else if chars.count == 1, let s = chars.unicodeScalars.first,
                              CharacterSet.letters.contains(s) {
                        nav.langSearchActive = true
                        nav.langSearch = chars
                        nav.langSelectedIndex = 0
                    }
                    return true
                } else {
                    // Search active: build the query from printable characters.
                    if chars.count == 1, let s = chars.unicodeScalars.first,
                       CharacterSet.alphanumerics.contains(s) || "+-#._".contains(chars) {
                        nav.langSearch += chars
                        nav.langSelectedIndex = 0
                    }
                    return true
                }
            }

            // If a text field outside the snippet editor has focus (e.g. tab name field),
            // pass all events through so AppKit can deliver them to that field.
            if store.editStep == 0, event.window?.firstResponder is NSTextView {
                return false
            }

            // ⌘= / ⌘- — adjust snippet font size globally (works in any mode).
            if flags.contains(.command), event.keyCode == 24 || event.keyCode == 27 {
                adjustFontSize(delta: event.keyCode == 24 ? 1 : -1)
                return true
            }


            func enterEdit() {
                let current = store.tabs[store.activeTab]
                if store.focusedIndex == nil, !current.isEmpty { store.focusedIndex = 0 }
                guard let i = store.focusedIndex, i < current.count else { return }
                store.editSnapshot = current[i]
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

            // ─── Delete confirmation overlay ─────────────────────────────────
            if let idx = store.pendingDeleteIndex {
                switch event.keyCode {
                case 36: // ↵ — confirm
                    if idx < store.tabs[tab].count {
                        performDelete(at: idx, store: store, tab: tab)
                    }
                    store.pendingDeleteIndex = nil
                    return true
                case 53: // Esc — cancel
                    store.pendingDeleteIndex = nil
                    return true
                default:
                    return true // swallow everything else while confirming
                }
            }

            // ─── Edit mode ───────────────────────────────────────────────────
            if store.editStep > 0 {
                // Don't interfere with IME composition (Chinese / Japanese / etc.).
                // If the first responder (or its field editor) has marked text, let
                // the IME process this keystroke — Enter/Esc/arrows drive candidate
                // selection while composing.
                if let responder = event.window?.firstResponder as? NSTextView,
                   responder.hasMarkedText() {
                    return false
                }

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
                    let autoPaste = (UserDefaults.standard.object(forKey: "fetchAutoPaste") as? Bool) ?? false
                    if autoPaste {
                        // Popover is about to close and paste into the previous app —
                        // skip the toast and flash; neither would be visible.
                        NotificationCenter.default.post(name: .closePopoverAndPaste, object: nil)
                    } else {
                        postToast("Copied")
                        onCopyFlash(i)
                    }
                }
                return true

            case 14 where flags == .command:        // ⌘E — enter edit mode
                enterEdit(); return true

            case 37 where flags.isEmpty:            // L — open language picker
                if let i = store.focusedIndex, i < snippets.count {
                    openLanguagePicker(at: i, nav: nav)
                }
                return true

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
                    onCopyFlash(i)
                }
                return true

            case 45 where flags.contains(.command): // ⌘N — new snippet
                store.addSnippet()
                store.focusedIndex = store.tabs[tab].count - 1
                enterEdit()
                return true

            case 2 where flags.contains(.command): // ⌘D — delete
                if let i = store.focusedIndex, i < snippets.count {
                    let confirm = (UserDefaults.standard.object(forKey: "fetchConfirmDelete") as? Bool) ?? true
                    if confirm {
                        store.pendingDeleteIndex = i
                    } else {
                        performDelete(at: i, store: store, tab: tab)
                    }
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
    var onFlagsChanged: ((NSEvent) -> Void)? = nil

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let v = KeyCatchingNSView()
        v.onKey = onKey
        v.onWindowResignKey = onWindowResignKey
        v.onFlagsChanged = onFlagsChanged
        return v
    }

    func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
        nsView.onKey = onKey
        nsView.onWindowResignKey = onWindowResignKey
        nsView.onFlagsChanged = onFlagsChanged
    }
}

final class KeyCatchingNSView: NSView {
    var onKey: ((NSEvent) -> Bool)?
    var onWindowResignKey: (() -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?
    private var localMonitor: Any?
    private var flagsMonitor: Any?
    private var resignObserver: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
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
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, let selfWindow = self.window,
                  event.window === selfWindow else { return event }
            self.onFlagsChanged?(event)
            return event
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
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
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

struct DeleteConfirmOverlay: View {
    let title: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            VStack(spacing: 12) {
                Text("Delete \"\(title.isEmpty ? "Untitled" : title)\"?")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 3) {
                        Button("Cancel", action: onCancel)
                            .keyboardShortcut(.cancelAction)
                        Text("(esc)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 3) {
                        Button("Delete", action: onConfirm)
                            .keyboardShortcut(.defaultAction)
                            .tint(.red)
                        Text("(enter)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .controlSize(.small)
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }
}

private struct TabSwitcherOverlay: View {
    let tabNames: [String]
    let activeTab: Int
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("[\(i + 1)]")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.40))
                            .frame(width: 28, alignment: .leading)
                        Text(tabNames[i])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(
                                i == activeTab
                                    ? Color.styleAccent(colorScheme, style: iconStyle)
                                    : .primary
                            )
                        Spacer()
                    }
                }
            }
            .frame(width: 260)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .transition(.opacity)
    }
}

// Keyboard-driven language picker. All key handling lives in the list's key
// monitor; this view is purely presentational and reflects the nav state.
private struct LanguagePickerOverlay: View {
    let current: String
    let search: String
    let searchActive: Bool
    let selectedIndex: Int
    let starred: [String]
    let onSelect: (String) -> Void
    let onToggleStar: (String) -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"

    private var accent: Color { Color.styleAccent(colorScheme, style: iconStyle) }

    // Both columns share this height so the scrollable list lines up with the
    // quick column instead of overflowing past it.
    private let panelHeight: CGFloat = 224

    var body: some View {
        let filtered = filteredLanguages(search)
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 10) {
                searchBar
                HStack(alignment: .top, spacing: 12) {
                    quickColumn
                    Divider()
                    allColumn(filtered)
                }
                .frame(height: panelHeight)
                Text("1–9 quick · / search · ↑↓ move · ↵ select · esc close")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .frame(width: 400)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .transition(.opacity)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if searchActive {
                // Cursor hugs the typed text (no gap in front of it).
                HStack(spacing: 1) {
                    Text(search)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(accent)
                        .frame(width: 1.5, height: 15)
                }
            } else {
                Text(search.isEmpty ? "Press / to search" : search)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(search.isEmpty ? .secondary : .primary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.primary.opacity(searchActive ? 0.10 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(searchActive ? accent.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var quickColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("QUICK")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            ForEach(Array(quickPicks(starred).enumerated()), id: \.element) { idx, lang in
                Button { onSelect(lang) } label: {
                    HStack(spacing: 6) {
                        Text(idx < 9 ? "\(idx + 1)" : "·")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(accent)
                            .frame(width: 15, alignment: .trailing)
                        Text(lang)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(lang == current ? accent : .primary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 140, alignment: .leading)
    }

    private func allColumn(_ filtered: [String]) -> some View {
      VStack(alignment: .leading, spacing: 3) {
        Text("ALL")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(filtered.enumerated()), id: \.element) { idx, lang in
                        let isSelected = idx == selectedIndex
                        let isStarred = starred.contains(lang)
                        HStack(spacing: 6) {
                            // Clickable star: toggles the language in/out of the
                            // left quick-pick column.
                            Button { onToggleStar(lang) } label: {
                                Image(systemName: isStarred ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(isSelected ? Color.white
                                                     : (isStarred ? accent : .secondary))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(width: 15)

                            Button { onSelect(lang) } label: {
                                HStack(spacing: 6) {
                                    Text(lang)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.white
                                                         : (lang == current ? accent : .primary))
                                    Spacer(minLength: 0)
                                    if lang == current {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(isSelected ? Color.white : accent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? accent.opacity(0.9) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .id(idx)
                    }
                    if filtered.isEmpty {
                        Text("No match")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }
            }
            .onChange(of: selectedIndex) { _, idx in
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(idx, anchor: .center) }
            }
        }
      }
      .frame(width: 200)
    }
}

private func performDelete(at i: Int, store: SnippetStore, tab: Int) {
    let snippets = store.tabs[tab]
    guard i < snippets.count else { return }
    store.deleteSnippet(id: snippets[i].id, tab: tab)
    let remaining = store.tabs[tab]
    store.focusedIndex = remaining.isEmpty ? nil : max(0, i - 1)
    postToast("Deleted")
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
