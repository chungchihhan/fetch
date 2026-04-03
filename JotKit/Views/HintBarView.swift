import SwiftUI

struct HintBarView: View {
    var isEditing: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(isEditing
                 ? "Tab switch fields · ↑↓ or Esc to save & exit"
                 : "↑↓ navigate · ↵ edit · ⌘C copy · ⌘N new · ⌘D delete")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
            Spacer()
            Button {
                NotificationCenter.default.post(name: .togglePanel, object: nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: .command)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .overlay(Divider(), alignment: .top)
    }
}
