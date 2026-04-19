import Foundation
import Observation

@Observable
final class SnippetStore {
    var tabs: [[Snippet]] = Array(repeating: [], count: 6)
    var activeTab: Int = 0
    var focusedIndex: Int? = nil
    var editStep: Int = 0          // 0 = browse, 1 = title edit, 2 = code edit

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

    /// Move the snippet at `from` so that it's inserted at `toOffset` in the same tab.
    /// Follows SwiftUI `Array.move(fromOffsets:toOffset:)` semantics: `toOffset` is the
    /// insertion slot in the array's original indexing. Adjacent offsets are a no-op.
    @discardableResult
    func moveSnippet(from: Int, toOffset: Int, tab: Int) -> Int? {
        var updated = tabs[tab]
        guard updated.indices.contains(from) else { return nil }
        let clamped = max(0, min(updated.count, toOffset))
        if clamped == from || clamped == from + 1 { return from }
        updated.move(fromOffsets: IndexSet(integer: from), toOffset: clamped)
        tabs[tab] = updated
        save(tab: tab)
        return from < clamped ? clamped - 1 : clamped
    }

    @discardableResult
    func moveSnippet(id: UUID, toOffset: Int, tab: Int) -> Int? {
        guard let from = tabs[tab].firstIndex(where: { $0.id == id }) else { return nil }
        return moveSnippet(from: from, toOffset: toOffset, tab: tab)
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
