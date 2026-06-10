import Foundation
import AppKit
import Observation

@Observable
final class Updater {
    static let shared = Updater()

    var isChecking = false
    var isInstalling = false
    var latestVersion: String?
    var statusMessage: String = ""
    var updateReady = false

    private let repoOwner = "chungchihhan"
    private let repoName = "fetch"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.compare(latest, currentVersion) > 0
    }

    /// The snippet data directory, resolved the same way AppDelegate builds the
    /// store: the user's custom path if set, otherwise ~/.config/fetch.
    static func resolvedDataDirectory() -> URL {
        let savedPath = UserDefaults.standard.string(forKey: "fetchDataDirectory") ?? ""
        return savedPath.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/fetch")
            : URL(fileURLWithPath: savedPath)
    }

    /// Snapshot the user's snippet data before applying an update, so a bad
    /// release can't cost them their snippets. Best-effort: returns the backup
    /// location, or nil if there was nothing to back up (or the copy failed).
    /// Backups live at <dataDir>/backup/pre-update-<version>-<timestamp>.
    /// The backup/ subfolder is excluded from each snapshot to prevent nesting.
    /// Only the 5 most recent backups are kept; older ones are pruned.
    @discardableResult
    func backUpData(dataDirectory: URL? = nil) -> URL? {
        let fm = FileManager.default
        let dataDir = dataDirectory ?? Self.resolvedDataDirectory()
        guard fm.fileExists(atPath: dataDir.path) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())

        let backupRoot = dataDir.appendingPathComponent("backup")
        let dest = backupRoot.appendingPathComponent("pre-update-\(currentVersion)-\(stamp)")

        do {
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            let items = try fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
            for item in items where item.lastPathComponent != "backup" {
                try fm.copyItem(at: item, to: dest.appendingPathComponent(item.lastPathComponent))
            }
            pruneBackups(in: backupRoot, keeping: 5)
            return dest
        } catch {
            return nil
        }
    }

    private func pruneBackups(in backupRoot: URL, keeping maxCount: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        // Sort by creation date, not name: the version sits before the
        // timestamp in the folder name, so a string sort would rank
        // pre-update-1.10.0 below pre-update-1.9.0 and prune the newest first.
        let backups = entries
            .filter { $0.lastPathComponent.hasPrefix("pre-update-") }
            .sorted { creationDate(of: $0) < creationDate(of: $1) }
        guard backups.count > maxCount else { return }
        for old in backups.prefix(backups.count - maxCount) {
            try? fm.removeItem(at: old)
        }
    }

    private func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    @MainActor
    func checkForUpdates(silent: Bool = false) async {
        if !silent { statusMessage = "Checking…" }
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            statusMessage = "Invalid update URL"
            return
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                statusMessage = "Couldn't read release info"
                return
            }
            let clean = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            latestVersion = clean
            if updateAvailable {
                statusMessage = "Update available: \(clean)"
            } else if !silent {
                statusMessage = "You're on the latest version."
            } else {
                statusMessage = ""
            }
        } catch {
            statusMessage = silent ? "" : "Check failed"
        }
    }

    @MainActor
    func installUpdate(completion: ((Bool) -> Void)? = nil) {
        guard !isInstalling else { return }
        isInstalling = true

        // Snapshot the user's data before replacing the app, in case the new
        // version mishandles it. Best-effort — never blocks the update.
        statusMessage = "Backing up your snippets…"
        backUpData()
        statusMessage = "Downloading and installing…"

        let cmd = #"""
        set -e
        curl -fsSL "https://github.com/\#(repoOwner)/\#(repoName)/releases/latest/download/Fetch.zip" -o /tmp/Fetch.zip
        unzip -oq /tmp/Fetch.zip -d /Applications
        xattr -cr /Applications/Fetch.app
        """#

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", cmd]

        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isInstalling = false
                let success = proc.terminationStatus == 0
                if success {
                    self.updateReady = true
                    self.statusMessage = "Update ready. Relaunch to apply."
                } else {
                    self.statusMessage = "Install failed (exit \(proc.terminationStatus))"
                }
                completion?(success)
            }
        }

        do {
            try p.run()
        } catch {
            isInstalling = false
            statusMessage = "Failed to run installer"
            completion?(false)
        }
    }

    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open /Applications/Fetch.app"]
        try? task.run()
        NSApp.terminate(nil)
    }

    private static func compare(_ a: String, _ b: String) -> Int {
        let aa = a.split(separator: ".").compactMap { Int($0) }
        let bb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aa.count, bb.count) {
            let av = i < aa.count ? aa[i] : 0
            let bv = i < bb.count ? bb[i] : 0
            if av != bv { return av - bv }
        }
        return 0
    }
}
