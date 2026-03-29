import Foundation

struct LocalCacheStore {
    private let loader: () throws -> RuntimeCache?
    private let saver: (RuntimeCache) throws -> Void

    init(fileManager: FileManager = .default) {
        let supportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let baseURL = (supportURL ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Clocker", isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
        let fileStore = JSONFileStore<RuntimeCache>(baseURL: baseURL)
        let fileName = "current-day.json"
        self.loader = {
            try fileStore.load(from: fileName)
        }
        self.saver = { cache in
            try fileStore.save(cache, to: fileName)
        }
    }

    init(
        loader: @escaping () throws -> RuntimeCache?,
        saver: @escaping (RuntimeCache) throws -> Void
    ) {
        self.loader = loader
        self.saver = saver
    }

    func load() throws -> RuntimeCache? {
        try loader()
    }

    func save(_ cache: RuntimeCache) throws {
        try saver(cache)
    }
}
