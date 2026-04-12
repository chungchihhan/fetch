import Foundation
import Observation

@Observable
final class SnippetStore {
    var tabs: [[Snippet]] = Array(repeating: [], count: 6)
    var activeTab: Int = 0

    private var storageDirectory: URL

    init(storageDirectory: URL = SnippetStore.defaultDirectory) {
        self.storageDirectory = storageDirectory
        loadAll()
    }

    static var defaultDirectory: URL {
        let config = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/fetch")
        try? FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        return config
    }

    func addSnippet() {
        var updated = tabs[activeTab]
        updated.append(Snippet(title: "", code: ""))
        tabs[activeTab] = updated           // explicit set → reliable @Observable notification
        save(tab: activeTab)
    }

    func deleteSnippet(id: UUID, tab: Int) {
        var updated = tabs[tab]
        updated.removeAll { $0.id == id }
        tabs[tab] = updated                 // explicit set → reliable @Observable notification
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

    func changeDirectory(to newURL: URL) {
        saveAll()
        try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        for i in 0..<6 {
            let src = fileURL(for: i)
            let dst = newURL.appendingPathComponent("tab\(i + 1).json")
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            try? FileManager.default.copyItem(at: src, to: dst)
        }
        storageDirectory = newURL
        loadAll()
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
