import SwiftUI

struct HintBarView: View {
    var isEditing: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(isEditing
                 ? "Tab/⇧Tab fields · ↵ save · Esc save · ⇧↵ newline"
                 : "↑↓ navigate · ↵ copy · ⌘E edit · ⌘N new · ⌘D delete")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.45))
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(Divider(), alignment: .top)
    }
}
