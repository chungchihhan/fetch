import SwiftUI

struct PopoverContentView: View {
    @Environment(SnippetStore.self) var store
    @State private var isEditing = false
    @AppStorage("fetchHeight") private var height: Double = 300
    @AppStorage("fetchWidth") private var width: Double = 380
    @AppStorage("fetchColorScheme") private var colorSchemeKey: String = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemeKey {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.55)
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
        .frame(width: CGFloat(width), height: CGFloat(height))
        .overlay(alignment: .bottom)   { ResizeHandle(height: $height) }
        .overlay(alignment: .leading)  { ResizeWidthHandle(width: $width) }
        .background(.clear)
        .preferredColorScheme(preferredScheme)
        .onReceive(NotificationCenter.default.publisher(for: .editModeChanged)) { note in
            isEditing = note.object as? Bool ?? false
        }
    }
}

// ── Vertical (height) handle ────────────────────────────────────────────────

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
                    let maxHeight = Double(NSScreen.main?.visibleFrame.height ?? 1200) - 40
                    height = max(200, min(maxHeight, proposed))
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
    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeUpDown) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// ── Horizontal (width) handle ────────────────────────────────────────────────

struct ResizeWidthHandle: View {
    @Binding var width: Double
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Wider hit area
            ResizeWidthDragView(width: $width)
                .frame(width: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(isHovering ? 0.25 : 0.12))
                .frame(width: 3, height: 36)
                .allowsHitTesting(false)
        }
        .onHover { isHovering = $0 }
    }
}

// NSView-based drag: uses absolute screen coords so the handle stays glued to the mouse
private struct ResizeWidthDragView: NSViewRepresentable {
    @Binding var width: Double

    func makeNSView(context: Context) -> WidthDragNSView {
        let v = WidthDragNSView()
        v.onWidth = { newWidth in
            let screenWidth = Double(NSScreen.main?.visibleFrame.width ?? 1200) - 40
            width = max(280, min(screenWidth, newWidth))
            NotificationCenter.default.post(name: .widthChanged, object: CGFloat(width))
        }
        return v
    }
    func updateNSView(_ nsView: WidthDragNSView, context: Context) {}
}

private final class WidthDragNSView: NSView {
    var onWidth: ((Double) -> Void)?

    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }

    override func mouseDown(with event: NSEvent) {}   // absorb to start drag tracking

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        // Right edge of the popover window stays fixed; width = rightEdge − mouseX
        let rightEdge = Double(window.frame.maxX)
        let mouseX    = Double(NSEvent.mouseLocation.x)
        onWidth?(rightEdge - mouseX)
    }

    override func mouseUp(with event: NSEvent) {}
}

// ── Shared ───────────────────────────────────────────────────────────────────

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
