import Foundation

/// Small helper for staging photo data on disk during the
/// capture → CreateChildScreen → save handoff.
///
/// Mirrors Android's "save photo to temp cache during workflow, delete after
/// successful creation or cancellation" pattern (FR-CP-003/FR-CP-004).
enum TempPhotoStore {
    static let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("createChild", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Writes JPEG data to a uniquely-named file in the temp directory.
    /// Returns the path string (matching the Android `tempPhotoPath` semantics).
    static func write(_ data: Data) throws -> String {
        let url = directory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    static func read(_ path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    static func remove(_ path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Delete files older than `maxAge` (default 1 hour). Mirrors Android's
    /// NFR-ST-003 "old temp files (>1 hour) shall be auto-deleted".
    static func purgeOld(maxAge: TimeInterval = 3600) {
        let now = Date()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for url in entries {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
            if now.timeIntervalSince(mod) > maxAge {
                try? fm.removeItem(at: url)
            }
        }
    }
}
