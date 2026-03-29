import Foundation

struct JSONFileStore<Record: Codable & Sendable> {
    let baseURL: URL
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save(_ value: Record, to fileName: String) throws {
        try ensureDirectory()
        let url = baseURL.appendingPathComponent(fileName)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load(from fileName: String) throws -> Record? {
        let url = baseURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(Record.self, from: data)
    }

    func loadAll() throws -> [Record] {
        guard FileManager.default.fileExists(atPath: baseURL.path()) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(Record.self, from: Data(contentsOf: $0)) }
    }
}
