import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: Int
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var toastMessage: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Tabs — left-aligned
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    Button("⌘\(i + 1)") { activeTab = i }
                    .buttonStyle(TabButtonStyle(isActive: activeTab == i))
                    .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: NSCursor.pointingHand.set()
                        case .ended:  NSCursor.arrow.set()
                        }
                    }
                }
            }

            Spacer()

            // Toast — top right
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.styleAccent(colorScheme, style: iconStyle))
                    .transition(.opacity)
                    .padding(.trailing, 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.15), value: toastMessage)
        .overlay(Divider(), alignment: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .toastMessage)) { note in
            toastMessage = note.object as? String
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { toastMessage = nil }
            }
        }
    }
}

struct TabButtonStyle: ButtonStyle {
    var isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        TabButtonBody(configuration: configuration, isActive: isActive)
    }
}

private struct TabButtonBody: View {
    let configuration: ButtonStyleConfiguration
    var isActive: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fetchTabFontSize") private var tabFontSize: Double = 10
    @AppStorage("fetchIconStyle") private var iconStyle: String = "foxfire"
    @State private var isHovering = false

    private var accent: Color { Color.styleAccent(colorScheme, style: iconStyle) }

    var body: some View {
        configuration.label
            .font(.system(size: CGFloat(tabFontSize), design: .monospaced))
            .foregroundStyle(isActive ? accent : .primary.opacity(isHovering ? 0.80 : 0.55))
            .padding(.vertical, 3)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? accent.opacity(0.15) : (isHovering ? Color.primary.opacity(0.07) : .clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? accent.opacity(0.40) : (isHovering ? Color.primary.opacity(0.18) : .clear), lineWidth: 1)
                    )
            )
            .onHover { isHovering = $0 }
    }
}

// Convenience hex color init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8) & 0xff) / 255
        let b = Double(int & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }

    static func styleAccent(_ scheme: ColorScheme, style: String) -> Color {
        switch style {
        case "gloaming":
            return scheme == .dark ? Color(hex: "#82b5d4") : Color(hex: "#2f6a9f")
        case "smoulder":
            return scheme == .dark ? Color(hex: "#d48a8a") : Color(hex: "#9f2f3f")
        default: // foxfire
            return scheme == .dark ? Color(hex: "#78c9ab") : Color(hex: "#2f8f6a")
        }
    }
}
