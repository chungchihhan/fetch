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

    /// The backup must live inside <dataDir>/backup/, not at the top level of
    /// the data directory, so the snapshot isn't itself loaded as snippet data.
    func test_backUpData_storesBackupInsideBackupSubfolder() throws {
        try "[]".write(to: dataDir.appendingPathComponent("tab1.json"), atomically: true, encoding: .utf8)

        let backup = try XCTUnwrap(Updater().backUpData(dataDirectory: dataDir))

        let backupSubfolder = dataDir.appendingPathComponent("backup")
        XCTAssertTrue(backup.path.hasPrefix(backupSubfolder.path + "/"),
                      "backup should be inside dataDir/backup/")
    }

    /// The backup folder must not contain a nested backup/ subfolder — copying
    /// the data dir while excluding backup/ prevents exponential growth.
    func test_backUpData_excludesBackupFolderFromSnapshot() throws {
        try "[]".write(to: dataDir.appendingPathComponent("tab1.json"), atomically: true, encoding: .utf8)

        let backup = try XCTUnwrap(Updater().backUpData(dataDirectory: dataDir))

        let nested = backup.appendingPathComponent("backup")
        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path),
                       "snapshot should not contain a nested backup/ folder")
    }

    /// After more than 5 backups, only the 5 most recent should remain.
    func test_backUpData_prunesOldBackupsKeepingLatestFive() throws {
        try "[]".write(to: dataDir.appendingPathComponent("tab1.json"), atomically: true, encoding: .utf8)

        let updater = Updater()
        // Seed 5 old backups directly in the backup folder
        let backupRoot = dataDir.appendingPathComponent("backup")
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        for i in 1...5 {
            let old = backupRoot.appendingPathComponent("pre-update-0.0.\(i)-20260101-00000\(i)")
            try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        }

        updater.backUpData(dataDirectory: dataDir)

        let remaining = try FileManager.default.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("pre-update-") }
        XCTAssertEqual(remaining.count, 5, "should keep exactly 5 backups")
        XCTAssertFalse(remaining.contains { $0.lastPathComponent == "pre-update-0.0.1-20260101-000001" },
                       "oldest backup should have been pruned")
    }

    /// No data directory yet (fresh install) — backup is a no-op, not a crash.
    func test_backUpData_returnsNilWhenNoDataDirectory() {
        let missing = tmpRoot.appendingPathComponent("does-not-exist")
        XCTAssertNil(Updater().backUpData(dataDirectory: missing))
    }
}
