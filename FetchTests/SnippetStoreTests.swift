import XCTest
@testable import Fetch

final class SnippetStoreTests: XCTestCase {
    var tmpDir: URL!
    var store: SnippetStore!

    override func setUp() {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = SnippetStore(storageDirectory: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_initialState_sixEmptyTabs() {
        XCTAssertEqual(store.tabs.count, 6)
        XCTAssertTrue(store.tabs.allSatisfy { $0.isEmpty })
    }

    func test_addSnippet_appendsToActiveTab() {
        store.activeTab = 0
        store.addSnippet()
        XCTAssertEqual(store.tabs[0].count, 1)
        XCTAssertEqual(store.tabs[1].count, 0)
    }

    func test_deleteSnippet_removesCorrectItem() {
        store.addSnippet()
        store.addSnippet()
        let idToDelete = store.tabs[0][0].id
        store.deleteSnippet(id: idToDelete, tab: 0)
        XCTAssertEqual(store.tabs[0].count, 1)
        XCTAssertNotEqual(store.tabs[0][0].id, idToDelete)
    }

    func test_saveAndLoad_roundtrip() throws {
        store.activeTab = 2
        store.addSnippet()
        store.tabs[2][0].title = "My command"
        store.tabs[2][0].code = "echo hi"
        store.save(tab: 2)

        let store2 = SnippetStore(storageDirectory: tmpDir)
        store2.load(tab: 2)
        XCTAssertEqual(store2.tabs[2].count, 1)
        XCTAssertEqual(store2.tabs[2][0].title, "My command")
    }

    func test_save_isAtomic_noPartialWrite() throws {
        store.addSnippet()
        store.save(tab: 0)
        let fileURL = tmpDir.appendingPathComponent("tab1.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Data-loss safeguards

    /// Regression for the v1.3.0 wipe: a file that exists but cannot be decoded
    /// (corruption, partial write, or a format from another version) must never
    /// be overwritten with the empty in-memory tab. saveAll() fires on every
    /// popover close, so an undecodable file would otherwise be clobbered.
    func test_saveAll_doesNotOverwriteFileThatFailedToLoad() throws {
        let url = tmpDir.appendingPathComponent("tab1.json")
        let original = #"{"some":"unrecognized data the decoder cannot read"}"#
        try original.write(to: url, atomically: true, encoding: .utf8)

        let store2 = SnippetStore(storageDirectory: tmpDir)
        XCTAssertTrue(store2.tabs[0].isEmpty, "undecodable file should leave the tab empty in memory")

        store2.saveAll()

        let after = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(after, original, "saveAll must not overwrite a tab that failed to load")
    }

    /// The load-failure guard must not break a brand-new install where no file
    /// exists yet — saving a genuinely new (empty-then-populated) tab must work.
    func test_newTab_withNoFile_canStillBeSaved() throws {
        let store2 = SnippetStore(storageDirectory: tmpDir)
        store2.activeTab = 0
        store2.addSnippet()

        let url = tmpDir.appendingPathComponent("tab1.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let reloaded = SnippetStore(storageDirectory: tmpDir)
        reloaded.load(tab: 0)
        XCTAssertEqual(reloaded.tabs[0].count, 1)
    }

    /// Each save keeps the prior version as a `.bak` so a future bug remains
    /// recoverable without external backups.
    func test_save_keepsBackupOfPreviousVersion() throws {
        store.activeTab = 0
        store.addSnippet()
        store.tabs[0][0].title = "first"
        store.save(tab: 0)
        store.tabs[0][0].title = "second"
        store.save(tab: 0)

        let bak = tmpDir.appendingPathComponent("tab1.json.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bak.path),
                      "save should keep a .bak copy of the prior version")

        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: bak)) as? [String: Any]
        let snippets = obj?["snippets"] as? [[String: Any]]
        XCTAssertEqual(snippets?.first?["title"] as? String, "first",
                       ".bak should hold the version from before the last save")
    }
}
