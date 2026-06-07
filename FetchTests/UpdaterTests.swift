import XCTest
@testable import Fetch

final class UpdaterTests: XCTestCase {
    var tmpRoot: URL!
    var dataDir: URL!

    override func setUp() {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        dataDir = tmpRoot.appendingPathComponent("fetch")
        try! FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    /// Clicking "Update" must snapshot the user's data first, so a bad release
    /// can't cost them their snippets.
    func test_backUpData_copiesAllFilesToTimestampedFolder() throws {
        let tab1 = dataDir.appendingPathComponent("tab1.json")
        let contents = #"{"name":"Others","snippets":[{"id":"X","title":"t","code":"c","language":"bash"}]}"#
        try contents.write(to: tab1, atomically: true, encoding: .utf8)

        let backup = Updater().backUpData(dataDirectory: dataDir)

        let backupURL = try XCTUnwrap(backup, "backUpData should return the backup location")
        let copied = backupURL.appendingPathComponent("tab1.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path), "tab file should be copied into the backup")
        XCTAssertEqual(try String(contentsOf: copied, encoding: .utf8), contents, "backup must be a faithful copy")
    }

    /// The backup must live OUTSIDE the data directory, so it isn't itself
    /// loaded, copied on a directory change, or clobbered by the next save.
    func test_backUpData_storesBackupOutsideDataDirectory() throws {
        try "[]".write(to: dataDir.appendingPathComponent("tab1.json"), atomically: true, encoding: .utf8)

        let backup = try XCTUnwrap(Updater().backUpData(dataDirectory: dataDir))

        XCTAssertFalse(backup.path.hasPrefix(dataDir.path + "/"),
                       "backup should not be nested inside the data directory")
    }

    /// No data directory yet (fresh install) — backup is a no-op, not a crash.
    func test_backUpData_returnsNilWhenNoDataDirectory() {
        let missing = tmpRoot.appendingPathComponent("does-not-exist")
        XCTAssertNil(Updater().backUpData(dataDirectory: missing))
    }
}
