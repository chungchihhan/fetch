import SwiftUI
import AppKit

// Reference-type state so mutations from the key handler always propagate
@Observable
private final class ListNavState {
    var focusedIndex: Int? = nil
    var isEditing: Bool = false
}

struct SnippetListView: View {
    @Environment(SnippetStore.self) var store
    @State private var nav = ListNavState()

    var snippets: [Snippet] { store.tabs[store.activeTab] }

    var body: some View {
        // Build a key handler that captures nav and store as references
        let handler = makeKeyHandler(nav: nav, store: store)

        KeyInterceptView(onKey: handler) {
            if snippets.isEmpty {
                Text("Press ⌘N to add a snippet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { i, _ in
                                SnippetRowView(
                                    snippet: binding(for: i),
                                    isFocused: nav.focusedIndex == i,
                                    isEditing: nav.isEditing && nav.focusedIndex == i,
                                    onTitleChange: { store.tabs[store.activeTab][i].title = $0 },
                                    onCodeChange: { store.tabs[store.activeTab][i].code = $0 }
                                )
                                .id(i)
                                .onTapGesture { nav.focusedIndex = i }
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
        .onChange(of: store.activeTab) { _, _ in
            nav.focusedIndex = snippets.isEmpty ? nil : 0
            nav.isEditing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
            if nav.focusedIndex == nil, !snippets.isEmpty {
                nav.focusedIndex = 0
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

            if nav.isEditing {
                switch event.keyCode {
                case 53: // Esc — save and exit edit
                    nav.isEditing = false
                    NotificationCenter.default.post(name: .editModeChanged, object: false)
                    store.save(tab: tab)
                    return true
                case 125, 126: // ↓↑ — save, exit edit, move focus
                    nav.isEditing = false
                    NotificationCenter.default.post(name: .editModeChanged, object: false)
                    store.save(tab: tab)
                    let delta = event.keyCode == 125 ? 1 : -1
                    if !snippets.isEmpty {
                        let current = nav.focusedIndex ?? (delta > 0 ? -1 : snippets.count)
                        nav.focusedIndex = max(0, min(snippets.count - 1, current + delta))
                    }
                    return true
                case 48: // Tab — pass through to text fields
                    return false
                default:
                    return false
                }
            }

            // Browse mode
            switch event.keyCode {
            case 125: // ↓
                if !snippets.isEmpty {
                    let current = nav.focusedIndex ?? -1
                    nav.focusedIndex = max(0, min(snippets.count - 1, current + 1))
                }
                return true
            case 126: // ↑
                if !snippets.isEmpty {
                    let current = nav.focusedIndex ?? snippets.count
                    nav.focusedIndex = max(0, min(snippets.count - 1, current - 1))
                }
                return true
            case 36: // Enter
                if nav.focusedIndex == nil, !snippets.isEmpty { nav.focusedIndex = 0 }
                if nav.focusedIndex != nil {
                    nav.isEditing = true
                    NotificationCenter.default.post(name: .editModeChanged, object: true)
                }
                return true
            case 53: // Esc
                NotificationCenter.default.post(name: NSPopover.willCloseNotification, object: nil)
                NSApp.hide(nil)
                return true
            case 8 where event.modifierFlags.contains(.command): // ⌘C
                if let i = nav.focusedIndex, i < snippets.count {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippets[i].code, forType: .string)
                }
                return true
            case 45 where event.modifierFlags.contains(.command): // ⌘N
                store.addSnippet()
                nav.focusedIndex = store.tabs[tab].count - 1
                nav.isEditing = true
                NotificationCenter.default.post(name: .editModeChanged, object: true)
                return true
            case 2 where event.modifierFlags.contains(.command): // ⌘D
                if let i = nav.focusedIndex, i < snippets.count {
                    store.deleteSnippet(id: snippets[i].id, tab: tab)
                    let remaining = store.tabs[tab]
                    nav.focusedIndex = remaining.isEmpty ? nil : max(0, i - 1)
                }
                return true
            default:
                return false
            }
        }
    }
}

// NSViewRepresentable that installs a local key monitor
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
