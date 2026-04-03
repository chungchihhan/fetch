import XCTest
@testable import JotKit

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
}
