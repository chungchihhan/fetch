import Foundation
import Observation

@Observable
final class SnippetStore {
    var tabs: [[Snippet]] = Array(repeating: [], count: 6)
    var activeTab: Int = 0
    var focusedIndex: Int? = nil
    var editStep: Int = 0          // 0 = browse, 1 = title edit, 2 = code edit
    var editSnapshot: Snippet? = nil   // snapshot taken when edit begins, used for undo

    let undoManager = UndoManager()

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
        let snippet = Snippet(title: "", code: "")
        insertSnippet(snippet, at: tabs[activeTab].count, tab: activeTab, actionName: "Add Snippet")
    }

    func deleteSnippet(id: UUID, tab: Int) {
        var updated = tabs[tab]
        guard let idx = updated.firstIndex(where: { $0.id == id }) else { return }
        let removed = updated.remove(at: idx)
        tabs[tab] = updated
        save(tab: tab)

        undoManager.registerUndo(withTarget: self) { [removed, idx, tab] store in
            store.insertSnippet(removed, at: idx, tab: tab, actionName: nil)
        }
        undoManager.setActionName("Delete Snippet")
    }

    private func insertSnippet(_ snippet: Snippet, at index: Int, tab: Int, actionName: String?) {
        var arr = tabs[tab]
        let safeIndex = min(max(0, index), arr.count)
        arr.insert(snippet, at: safeIndex)
        tabs[tab] = arr
        save(tab: tab)

        let id = snippet.id
        undoManager.registerUndo(withTarget: self) { [id, tab] store in
            store.deleteSnippet(id: id, tab: tab)
        }
        if let actionName { undoManager.setActionName(actionName) }
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

        let finalIndex = from < clamped ? clamped - 1 : clamped
        // To undo: move back so the snippet lands at the original `from` index.
        let inverseOffset = from < clamped ? from : from + 1
        undoManager.registerUndo(withTarget: self) { [finalIndex, inverseOffset, tab] store in
            _ = store.moveSnippet(from: finalIndex, toOffset: inverseOffset, tab: tab)
        }
        undoManager.setActionName("Move Snippet")
        return finalIndex
    }

    /// Replace the snippet with `id` by `newValue` (preserving position). Registers undo.
    func replaceSnippet(id: UUID, with newValue: Snippet, tab: Int) {
        var arr = tabs[tab]
        guard let idx = arr.firstIndex(where: { $0.id == id }) else { return }
        let old = arr[idx]
        arr[idx] = newValue
        tabs[tab] = arr
        save(tab: tab)

        undoManager.registerUndo(withTarget: self) { [old, tab, id] store in
            store.replaceSnippet(id: id, with: old, tab: tab)
        }
        undoManager.setActionName("Edit Snippet")
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
