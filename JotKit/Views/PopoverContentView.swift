import SwiftUI

struct PopoverContentView: View {
    @Environment(SnippetStore.self) var store
    @State private var isEditing = false
    @AppStorage("jotkitHeight") private var height: Double = 300

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
        .frame(width: 380, height: CGFloat(height))
        .overlay(alignment: .bottom) { ResizeHandle(height: $height) }
        .background(.clear)
        .onReceive(NotificationCenter.default.publisher(for: .editModeChanged)) { note in
            isEditing = note.object as? Bool ?? false
        }
    }
}

struct ResizeHandle: View {
    @Binding var height: Double
    @State private var dragStartHeight: Double? = nil
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Color.clear.frame(height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(isHovering ? 0.25 : 0.12))
                .frame(width: 36, height: 3)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .overlay(ResizeCursorView())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = height }
                    let proposed = (dragStartHeight ?? height) + Double(value.translation.height)
                    height = max(200, min(700, proposed))
                    NotificationCenter.default.post(name: .heightChanged, object: CGFloat(height))
                }
                .onEnded { _ in dragStartHeight = nil }
        )
    }
}

private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorNSView { ResizeCursorNSView() }
    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {}
}

final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
