import SwiftUI
import AppKit

struct SnippetListView: View {
    @Environment(SnippetStore.self) var store
    @State private var focusedIndex: Int? = nil
    @State private var isEditing: Bool = false

    var snippets: [Snippet] { store.tabs[store.activeTab] }

    var body: some View {
        KeyInterceptView(onKey: handleKey) {
            if snippets.isEmpty {
                Text("Press ⌘N to add a snippet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { i, snippet in
                                SnippetRowView(
                                    snippet: binding(for: i),
                                    isFocused: focusedIndex == i,
                                    isEditing: isEditing && focusedIndex == i,
                                    onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
                                    onCodeChange: { store.tabs[store.activeTab][i].code = $0 }
                                )
                                .id(i)
                                .onTapGesture { focusedIndex = i }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: focusedIndex) { _, idx in
                        if let idx { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }
        }
        .onChange(of: store.activeTab) { _, _ in
            focusedIndex = snippets.isEmpty ? nil : 0
            isEditing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
            if focusedIndex == nil, !snippets.isEmpty {
                focusedIndex = 0
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

    private func handleKey(_ event: NSEvent) -> Bool {
        let tab = store.activeTab

        if isEditing {
            switch event.keyCode {
            case 53: // Esc — save and exit edit
                isEditing = false
                NotificationCenter.default.post(name: .editModeChanged, object: false)
                store.save(tab: tab)
                return true
            case 125, 126: // ↓↑ — save, exit edit, move focus
                isEditing = false
                NotificationCenter.default.post(name: .editModeChanged, object: false)
                store.save(tab: tab)
                moveFocus(by: event.keyCode == 125 ? 1 : -1)
                return true
            case 48: // Tab — let it pass through to SwiftUI text fields
                return false
            default:
                return false // let typing pass through to text fields
            }
        }

        // Browse mode
        switch event.keyCode {
        case 125: moveFocus(by: 1); return true        // ↓
        case 126: moveFocus(by: -1); return true       // ↑
        case 36:                                        // Enter
            if focusedIndex == nil, !snippets.isEmpty { focusedIndex = 0 }
            enterEditMode(); return true
        case 53:  closeApp(); return true              // Esc
        case 8 where event.modifierFlags.contains(.command): // ⌘C
            copyFocusedCode(); return true
        case 45 where event.modifierFlags.contains(.command): // ⌘N
            addSnippet(); return true
        case 2 where event.modifierFlags.contains(.command):  // ⌘D
            deleteFocused(); return true
        default: return false
        }
    }

    private func moveFocus(by delta: Int) {
        guard !snippets.isEmpty else { return }
        let current = focusedIndex ?? (delta > 0 ? -1 : snippets.count)
        focusedIndex = max(0, min(snippets.count - 1, current + delta))
    }

    private func enterEditMode() {
        guard focusedIndex != nil else { return }
        isEditing = true
        NotificationCenter.default.post(name: .editModeChanged, object: true)
    }

    private func copyFocusedCode() {
        guard let i = focusedIndex, i < snippets.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippets[i].code, forType: .string)
    }

    private func addSnippet() {
        store.addSnippet()
        focusedIndex = snippets.count - 1
        isEditing = true
    }

    private func deleteFocused() {
        guard let i = focusedIndex, i < snippets.count else { return }
        let id = snippets[i].id
        store.deleteSnippet(id: id, tab: store.activeTab)
        if snippets.isEmpty {
            focusedIndex = nil
        } else {
            focusedIndex = max(0, i - 1)
        }
    }

    private func closeApp() {
        NotificationCenter.default.post(name: NSPopover.willCloseNotification, object: nil)
        NSApp.hide(nil)
    }
}

// NSViewRepresentable that intercepts key events before SwiftUI sees them
struct KeyInterceptView<Content: View>: NSViewRepresentable {
    let onKey: (NSEvent) -> Bool
    let content: Content

    init(onKey: @escaping (NSEvent) -> Bool, @ViewBuilder content: () -> Content) {
        self.onKey = onKey
        self.content = content()
    }

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let v = KeyCatchingNSView()
        v.onKey = onKey
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: v.topAnchor),
            host.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: v.trailingAnchor),
        ])
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
}
