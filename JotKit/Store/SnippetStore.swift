import Foundation
import Observation

@Observable
final class SnippetStore {
    var tabs: [[Snippet]] = Array(repeating: [], count: 6)
    var activeTab: Int = 0

    private let storageDirectory: URL

    init(storageDirectory: URL = Self.defaultDirectory) {
        self.storageDirectory = storageDirectory
        loadAll()
    }

    static var defaultDirectory: URL {
        let config = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jotkit")
        try? FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        return config
    }

    func addSnippet() {
        tabs[activeTab].append(Snippet(title: "", code: ""))
        save(tab: activeTab)
    }

    func deleteSnippet(id: UUID, tab: Int) {
        tabs[tab].removeAll { $0.id == id }
        save(tab: tab)
    }

    func save(tab: Int) {
        let url = fileURL(for: tab)
        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            let data = try JSONEncoder().encode(tabs[tab])
            try data.write(to: tmpURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    func saveAll() {
        for i in 0..<6 { save(tab: i) }
    }

    func load(tab: Int) {
        let url = fileURL(for: tab)
        guard let data = try? Data(contentsOf: url),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data)
        else { return }
        tabs[tab] = snippets
    }

    private func loadAll() {
        for i in 0..<6 { load(tab: i) }
    }

    private func fileURL(for tab: Int) -> URL {
        storageDirectory.appendingPathComponent("tab\(tab + 1).json")
    }
}
