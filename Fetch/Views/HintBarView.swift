import SwiftUI

struct HintBarView: View {
    var isEditing: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Text(isEditing
                 ? "Tab/⇧Tab fields · ↵ save · Esc save · ⇧↵ newline"
                 : "↑↓ navigate · ↵ copy · ⌘E edit · ⌘N new · ⌘D delete · ⌘Z undo")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary.opacity(colorScheme == .dark ? 0.45 : 0.70))
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(Divider(), alignment: .top)
        .overlay(alignment: .trailing) {
            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.40))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings (⌘,)")
            .padding(.trailing, 12)
        }
    }
}
