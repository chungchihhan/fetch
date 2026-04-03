import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { i in
                Button("⌘\(i + 1)") { activeTab = i }
                .buttonStyle(TabButtonStyle(isActive: activeTab == i))
                .keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .overlay(Divider(), alignment: .bottom)
    }
}

struct TabButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(isActive ? Color(hex: "#89b4fa") : .white.opacity(0.28))
            .padding(.vertical, 3)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color(hex: "#89b4fa").opacity(0.18) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? Color(hex: "#89b4fa").opacity(0.35) : .clear, lineWidth: 1)
                    )
            )
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
}
