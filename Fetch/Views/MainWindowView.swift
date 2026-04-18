import SwiftUI

struct MainWindowView: View {
    @Environment(SnippetStore.self) var store
    @State private var isEditing = false
    @AppStorage("fetchColorScheme") private var colorSchemeKey: String = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemeKey {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(activeTab: Binding(
                get: { store.activeTab },
                set: { store.activeTab = $0 }
            ))
            SnippetListView()
            HintBarView(isEditing: isEditing)
        }
        .frame(minWidth: 380, minHeight: 300)
        .preferredColorScheme(preferredScheme)
        .onReceive(NotificationCenter.default.publisher(for: .editModeChanged)) { note in
            isEditing = note.object as? Bool ?? false
        }
    }
}
