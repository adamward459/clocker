import Foundation

/// Writes the current time to a daily file in the storage folder.
/// All I/O runs on a dedicated background queue — never blocks the main thread.
final class TimeWriter: @unchecked Sendable {
    private let storageURL: URL
    private let queue = DispatchQueue(label: "com.clocker.timewriter", qos: .utility)

    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Safe to call from any thread.
    func persist(_ time: String) {
        let url = storageURL
        queue.async {
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let fileName = fmt.string(from: Date()) + ".txt"
            let fileURL = url.appendingPathComponent(fileName)
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
        let url = storageURL
        queue.sync {
            let fm = FileManager.default
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let fileName = fmt.string(from: Date()) + ".txt"
            let fileURL = url.appendingPathComponent(fileName)

            try? fm.removeItem(at: fileURL)
        }
    }

    /// Waits until all previously queued work has completed.
    /// Useful for tests that need deterministic file-system state.
    func waitUntilIdle() {
        queue.sync { }
    }
}
