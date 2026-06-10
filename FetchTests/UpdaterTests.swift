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

        let fm = FileManager.default
        let updater = Updater()
        // Seed 5 old backups with explicit, increasing creation dates so the
        // oldest is unambiguous regardless of folder-name ordering.
        let backupRoot = dataDir.appendingPathComponent("backup")
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 1...5 {
            let old = backupRoot.appendingPathComponent("pre-update-0.0.\(i)-seed")
            try fm.createDirectory(at: old, withIntermediateDirectories: true)
            try fm.setAttributes([.creationDate: base.addingTimeInterval(Double(i))], ofItemAtPath: old.path)
        }

        updater.backUpData(dataDirectory: dataDir)

        let remaining = try fm.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("pre-update-") }
        XCTAssertEqual(remaining.count, 5, "should keep exactly 5 backups")
        XCTAssertFalse(remaining.contains { $0.lastPathComponent == "pre-update-0.0.1-seed" },
                       "oldest backup (earliest creation date) should have been pruned")
    }

    /// Pruning ranks by creation date, not folder name — so a higher version
    /// number that sorts lower as a string (1.10 < 1.9) is still kept when newer.
    func test_backUpData_prunesByCreationDateNotName() throws {
        try "[]".write(to: dataDir.appendingPathComponent("tab1.json"), atomically: true, encoding: .utf8)

        let fm = FileManager.default
        let backupRoot = dataDir.appendingPathComponent("backup")
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Names that sort the OPPOSITE of chronological order: "1.10.0" < "1.9.0"
        // as strings, but 1.10.0 is the newer (later-created) backup.
        let older = backupRoot.appendingPathComponent("pre-update-1.9.0-x")
        let newer = backupRoot.appendingPathComponent("pre-update-1.10.0-x")
        try fm.createDirectory(at: older, withIntermediateDirectories: true)
        try fm.createDirectory(at: newer, withIntermediateDirectories: true)
        try fm.setAttributes([.creationDate: base], ofItemAtPath: older.path)
        try fm.setAttributes([.creationDate: base.addingTimeInterval(100)], ofItemAtPath: newer.path)
        // Pad so that with the real backup added below there are 6 total,
        // and exactly one (the oldest) gets pruned.
        for i in 1...3 {
            let pad = backupRoot.appendingPathComponent("pre-update-2.0.\(i)-x")
            try fm.createDirectory(at: pad, withIntermediateDirectories: true)
            try fm.setAttributes([.creationDate: base.addingTimeInterval(Double(200 + i))], ofItemAtPath: pad.path)
        }

        Updater().backUpData(dataDirectory: dataDir)

        let names = try fm.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("pre-update-") }
        XCTAssertFalse(names.contains("pre-update-1.9.0-x"), "the older backup should be pruned")
        XCTAssertTrue(names.contains("pre-update-1.10.0-x"), "the newer backup must survive despite its lower-sorting name")
    }

    /// No data directory yet (fresh install) — backup is a no-op, not a crash.
    func test_backUpData_returnsNilWhenNoDataDirectory() {
        let missing = tmpRoot.appendingPathComponent("does-not-exist")
        XCTAssertNil(Updater().backUpData(dataDirectory: missing))
    }
}
