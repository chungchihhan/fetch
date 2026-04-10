import SwiftUI

struct HintBarView: View {
    var isEditing: Bool
    var showPanelButton: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(isEditing
                 ? "Tab/⇧Tab fields · ↵ save · Esc save · ⇧↵ newline"
                 : "↑↓ navigate · ↵ copy · ⌘E edit · ⌘N new · ⌘D delete")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.45))
            Spacer()
            if showPanelButton {
                Button {
                    NotificationCenter.default.post(name: .togglePanel, object: nil)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.40))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: .command)
                .padding(.trailing, 12)
            }
        }
        .padding(.vertical, 6)
        .overlay(Divider(), alignment: .top)
    }
}
