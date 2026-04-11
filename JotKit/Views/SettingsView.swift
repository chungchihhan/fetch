import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(SnippetStore.self) var store
    @AppStorage("jotkitColorScheme") private var colorSchemeKey: String = "system"
    @AppStorage("jotkitDataDirectory") private var dataDirectory: String = ""
    @AppStorage("jotkitCodeWrap") private var codeWrap: Bool = false

    private var displayPath: String {
        dataDirectory.isEmpty ? SnippetStore.defaultDirectory.path : dataDirectory
    }

    var body: some View {
        VStack(spacing: 0) {
            settingRow {
                Text("Appearance")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: $colorSchemeKey) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Divider()

            settingRow {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Data Folder")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(displayPath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .leading)
                }

                Spacer()

                Button("Browse…") { pickFolder() }
            }

            Divider()

            settingRow {
                Text("Code Wrap")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: $codeWrap)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding(20)
        .frame(width: 360)
        .onChange(of: colorSchemeKey) { _, newValue in
            (NSApp.delegate as? AppDelegate)?.applyAppearance(newValue)
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center) {
            content()
        }
        .padding(.vertical, 12)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for JotKit data"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        dataDirectory = url.path
        store.changeDirectory(to: url)
    }
}
