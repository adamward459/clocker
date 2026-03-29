import Foundation

struct ExternalFolderBookmarkStore {
    private let defaults: UserDefaults
    private let key = "selectedExportFolderBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    func loadURL() -> URL? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            try? save(url: url)
        }

        return url
    }
}
