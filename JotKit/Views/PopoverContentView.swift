import SwiftUI

struct PopoverContentView: View {
    @Environment(SnippetStore.self) var store
    @State private var isEditing = false

    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabBarView(activeTab: Binding(
                    get: { store.activeTab },
                    set: { store.activeTab = $0 }
                ))

                SnippetListView()

                HintBarView(isEditing: isEditing)
            }
        }
        .frame(width: 380, height: 300)
        .background(.clear)
        // Propagate edit state up for HintBarView
        .onReceive(NotificationCenter.default.publisher(for: .editModeChanged)) { note in
            isEditing = note.object as? Bool ?? false
        }
    }
}

// NSVisualEffectView wrapper for frosted glass
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// Note: editModeChanged and popoverDidOpen are defined in SnippetListView.swift.
