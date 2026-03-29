import Foundation

protocol DailyRecordStoreProtocol: Sendable {
    func loadAll() async throws -> [DailyRecord]
    func save(_ record: DailyRecord) async throws
    func existingFileNames() async throws -> Set<String>
}

struct DailyRecordStore: DailyRecordStoreProtocol {
    private let fileStore: JSONFileStore<DailyRecord>
    private let requiresSecurityScopedAccess: Bool

    init(baseURL: URL, requiresSecurityScopedAccess: Bool = false) {
        self.fileStore = JSONFileStore(baseURL: baseURL)
        self.requiresSecurityScopedAccess = requiresSecurityScopedAccess
    }

    func loadAll() async throws -> [DailyRecord] {
        try withAccess {
            try fileStore.loadAll()
        }
    }

    func save(_ record: DailyRecord) async throws {
        try withAccess {
            try fileStore.save(record, to: "\(record.dateKey).json")
        }
    }

    func existingFileNames() async throws -> Set<String> {
        try withAccess {
            try fileStore.ensureDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: fileStore.baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return Set(urls.map(\.lastPathComponent))
        }
    }

    private func withAccess<T>(_ operation: () throws -> T) throws -> T {
        guard requiresSecurityScopedAccess else {
            return try operation()
        }

        let didAccess = fileStore.baseURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileStore.baseURL.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }
}
