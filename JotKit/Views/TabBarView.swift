import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: Int
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
                }
            }

            Spacer()

            // Toast — top right
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(hex: "#78c9ab"))
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
        configuration.label
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(isActive ? Color(hex: "#78c9ab") : .black.opacity(0.55))
            .padding(.vertical, 3)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color(hex: "#78c9ab").opacity(0.15) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActive ? Color(hex: "#78c9ab").opacity(0.40) : .clear, lineWidth: 1)
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
