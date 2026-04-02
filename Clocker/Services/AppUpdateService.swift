import AppUpdater
import Foundation

@MainActor
final class AppUpdateService: ObservableObject {
    private let updater: AppUpdater?

    var isAvailable: Bool {
        updater != nil
    }

    init() {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".dev") != true else {
            updater = nil
            return
        }

        let updater = AppUpdater(
            owner: "adamward459",
            repo: "clocker",
            releasePrefix: "Clocker",
            provider: NormalizedGithubReleaseProvider()
        )
        updater.skipCodeSignValidation = true
        updater.onDownloadSuccess = { [weak updater] in
            updater?.install()
        }
        updater.onDownloadFail = { [weak updater] error in
            guard !error.isCancelled else { return }
            Task { @MainActor in
                updater?.lastError = error
            }
        }
        self.updater = updater
    }

    func checkForUpdates() {
        updater?.check()
    }
}

private struct NormalizedGithubReleaseProvider: ReleaseProvider {
    private let baseProvider = GithubReleaseProvider()

    func fetchReleases(owner: String, repo: String, proxy: URLRequestProxy?) async throws -> [Release] {
        let slug = "\(owner)/\(repo)"
        let url = URL(string: "https://api.github.com/repos/\(slug)/releases")!

        let request = URLRequest(url: url).applyOrOriginal(proxy: proxy)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AUError.invalidCallingConvention
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CRTHTTPError.badStatusCode(httpResponse.statusCode, data, httpResponse)
        }

        let normalizedData = GitHubReleaseNormalizer.normalizeReleasePayload(data)
        return try JSONDecoder().decode([Release].self, from: normalizedData)
    }

    func download(asset: Release.Asset, to saveLocation: URL, proxy: URLRequestProxy?) async throws -> AsyncThrowingStream<DownloadingState, Error> {
        try await baseProvider.download(asset: asset, to: saveLocation, proxy: proxy)
    }

    func fetchAssetData(asset: Release.Asset, proxy: URLRequestProxy?) async throws -> Data {
        try await baseProvider.fetchAssetData(asset: asset, proxy: proxy)
    }

}

enum GitHubReleaseNormalizer {
    static func normalizeReleasePayload(_ data: Data) -> Data {
        guard
            var releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return data
        }

        for index in releases.indices {
            guard
                let rawTag = releases[index]["tag_name"] as? String,
                let normalizedTag = normalizeTag(rawTag)
            else {
                continue
            }

            releases[index]["tag_name"] = normalizedTag

            guard var assets = releases[index]["assets"] as? [[String: Any]] else {
                continue
            }

            for assetIndex in assets.indices {
                guard let name = assets[assetIndex]["name"] as? String else {
                    continue
                }

                assets[assetIndex]["name"] = normalizeAssetName(name, rawTag: rawTag, normalizedTag: normalizedTag)
            }

            releases[index]["assets"] = assets
        }

        return (try? JSONSerialization.data(withJSONObject: releases)) ?? data
    }

    private static func normalizeTag(_ rawTag: String) -> String? {
        guard rawTag.hasPrefix("v"), rawTag.dropFirst().first?.isNumber == true else {
            return nil
        }
        return String(rawTag.dropFirst())
    }

    private static func normalizeAssetName(_ name: String, rawTag: String, normalizedTag: String) -> String {
        let token = "-\(rawTag)"
        guard name.contains(token) else {
            return name
        }
        return name.replacingOccurrences(of: token, with: "-\(normalizedTag)")
    }
}
