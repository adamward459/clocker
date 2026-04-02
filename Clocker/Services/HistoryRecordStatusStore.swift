import Foundation

final class HistoryRecordStatusStore {
    private struct StatusPayload: Codable {
        let isDone: Bool
    }

    private let queue = DispatchQueue(label: "com.clocker.history-status-store", qos: .utility)

    func isDone(for fileURL: URL) -> Bool {
        queue.sync {
            let statusURL = Self.statusFileURL(for: fileURL)
            guard let data = try? Data(contentsOf: statusURL),
                  let payload = try? JSONDecoder().decode(StatusPayload.self, from: data)
            else {
                return false
            }

            return payload.isDone
        }
    }

    func setDone(_ isDone: Bool, for fileURL: URL) {
        queue.sync {
            let statusURL = Self.statusFileURL(for: fileURL)
            let fm = FileManager.default

            if isDone {
                let payload = StatusPayload(isDone: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                guard let data = try? encoder.encode(payload) else { return }
                let directoryURL = statusURL.deletingLastPathComponent()
                if !fm.fileExists(atPath: directoryURL.path) {
                    try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                }
                try? data.write(to: statusURL, options: [.atomic])
            } else {
                try? fm.removeItem(at: statusURL)
            }
        }
    }

    static func statusFileURL(for fileURL: URL) -> URL {
        fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).status.json")
    }
}
