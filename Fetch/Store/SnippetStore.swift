import Foundation
import Observation

private struct TabFile: Codable {
    var name: String
    var snippets: [Snippet]
}

@Observable
final class SnippetStore {
    var tabs: [[Snippet]] = Array(repeating: [], count: 6)
    var activeTab: Int = 0
    var focusedIndex: Int? = nil
    var editStep: Int = 0          // 0 = browse, 1 = title edit, 2 = code edit
    var editSnapshot: Snippet? = nil   // snapshot taken when edit begins, used for undo
    private(set) var tabNames: [String] = (1...6).map { "Tab \($0)" }
    var pendingDeleteIndex: Int? = nil // non-nil = confirm-delete overlay is up
    // One-shot cursor placement when entering edit via click; consumed by the
    // text field once it's focused, then cleared.
    var pendingCursorIndex: Int? = nil

    let undoManager = UndoManager()

    private var storageDirectory: URL

    // Per-tab guard: a tab may only be written to disk once we know its file is
    // safe to overwrite — i.e. it loaded successfully OR no file existed yet.
    // If a file exists but can't be read/decoded, we must NOT clobber it with
    // the empty in-memory tab (the v1.3.0 data-loss bug). Defaults to true so a
    // fresh install with no files can still save.
    private var loadSucceeded: [Bool] = Array(repeating: true, count: 6)

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

    func renameTab(_ tab: Int, name: String) {
        guard tabNames.indices.contains(tab) else { return }
        tabNames[tab] = name
        save(tab: tab)
    }

    func save(tab: Int) {
        // Never overwrite a file we couldn't load — that's how empty in-memory
        // tabs wipe real data on the next popover-close / quit.
        guard loadSucceeded[tab] else { return }

        let url = fileURL(for: tab)
        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            let file = TabFile(name: tabNames[tab], snippets: tabs[tab])
            let data = try JSONEncoder().encode(file)
            try data.write(to: tmpURL, options: .atomic)

            // Keep the previous good version as a .bak so any future bug is
            // recoverable without external backups.
            if FileManager.default.fileExists(atPath: url.path) {
                let bakURL = url.appendingPathExtension("bak")
                try? FileManager.default.removeItem(at: bakURL)
                try? FileManager.default.copyItem(at: url, to: bakURL)
            }

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

        // No file yet (fresh install / never-used tab) — genuinely empty, and
        // safe to write later.
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadSucceeded[tab] = true
            return
        }

        // File exists but can't be read — do NOT allow an overwrite that would
        // destroy it. Leave the tab empty in memory and block saves for it.
        guard let data = try? Data(contentsOf: url) else {
            loadSucceeded[tab] = false
            return
        }

        if let file = try? JSONDecoder().decode(TabFile.self, from: data) {
            tabs[tab] = file.snippets
            tabNames[tab] = file.name
            loadSucceeded[tab] = true
        } else if let snippets = try? JSONDecoder().decode([Snippet].self, from: data) {
            // Old bare-array format — migrate silently.
            tabs[tab] = snippets
            tabNames[tab] = "Tab \(tab + 1)"
            loadSucceeded[tab] = true
            save(tab: tab)
        } else {
            // File exists but matches no known format (corruption, partial
            // write, or an unrecognized version). Preserve it — never clobber.
            loadSucceeded[tab] = false
        }
    }

    private func loadAll() {
        for i in 0..<6 { load(tab: i) }
        migrateLegacyLanguagesIfNeeded()
    }

    // Before the per-snippet language picker existed, every snippet was stored
    // with the old hardcoded default "bash" (no language was ever chosen). Map
    // those to "auto" once so existing snippets get auto-detected highlighting.
    // A flag makes this run a single time, so a future explicit "bash" pick is
    // preserved. Only rewrites tabs that loaded successfully (never clobbers a
    // file we couldn't read).
    private func migrateLegacyLanguagesIfNeeded() {
        let flag = "fetchLanguageMigratedV1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        for tab in 0..<6 where loadSucceeded[tab] {
            var changed = false
            for i in tabs[tab].indices where tabs[tab][i].language == "bash" {
                tabs[tab][i].language = "auto"
                changed = true
            }
            if changed { save(tab: tab) }
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    private func fileURL(for tab: Int) -> URL {
        storageDirectory.appendingPathComponent("tab\(tab + 1).json")
    }
}
