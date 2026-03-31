import Foundation

/// Writes the current time to a daily file in the storage folder.
/// All I/O runs on a dedicated background queue — never blocks the main thread.
final class TimeWriter: @unchecked Sendable {
    let storageURL: URL
    private let queue = DispatchQueue(label: "com.clocker.timewriter", qos: .utility)

    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Safe to call from any thread.
    func persist(_ time: String) {
        persist(time, projectID: ClockProject.defaultID)
    }

    /// Safe to call from any thread.
    func persist(_ time: String, projectID: String) {
        let url = storageURL
        queue.async {
            let fm = FileManager.default
            let fileURL = Self.currentDayFileURL(storageURL: url, projectID: projectID)
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: directoryURL.path) {
                try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            let line = time + "\n"

            if fm.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(Data(line.utf8))
                    handle.closeFile()
                }
            } else {
                try? line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Removes today's record from disk.
    /// Uses the same queue as writes so any queued persist finishes first.
    func clearTodayRecord() {
        clearTodayRecord(projectID: ClockProject.defaultID)
    }

    /// Removes today's record for a specific project from disk.
    /// Uses the same queue as writes so any queued persist finishes first.
    func clearTodayRecord(projectID: String) {
        let url = storageURL
        queue.sync {
            let fm = FileManager.default
            let fileURL = Self.currentDayFileURL(storageURL: url, projectID: projectID)

            try? fm.removeItem(at: fileURL)
        }
    }

    /// Waits until all previously queued work has completed.
    /// Useful for tests that need deterministic file-system state.
    func waitUntilIdle() {
        queue.sync { }
    }

    static func currentDayFileURL(storageURL: URL, projectID: String = ClockProject.defaultID, date: Date = Date()) -> URL {
        let baseURL = projectDirectoryURL(storageURL: storageURL, projectID: projectID)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let fileName = fmt.string(from: date) + ".txt"
        return baseURL.appendingPathComponent(fileName)
    }

    private static func projectDirectoryURL(storageURL: URL, projectID: String) -> URL {
        guard projectID != ClockProject.defaultID else {
            return storageURL
        }

        return storageURL.appendingPathComponent(projectID, isDirectory: true)
    }
}
