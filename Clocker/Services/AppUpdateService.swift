import AppUpdater
import Combine
import Foundation
import Version

@MainActor
final class AppUpdateService: ObservableObject {
    private let updater: AppUpdater?
    private var stateObservation: AnyCancellable?

    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var lastError: Error?

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
        self.updater = updater
        updater.skipCodeSignValidation = true
        updater.onDownloadSuccess = { [weak self, weak updater] in
            Task { @MainActor in
                self?.status = .installing(version: self?.currentStatusVersion ?? "latest")
            }
            updater?.install()
        }
        updater.onDownloadFail = { [weak self] error in
            Task { @MainActor in
                self?.handleFailure(error)
            }
        }
        stateObservation = updater.$state.sink { [weak self] state in
            Task { @MainActor in
                self?.status = UpdateStatus(state: state)
            }
        }
        status = .idle
    }

    func checkForUpdates() {
        guard let updater else { return }
        status = .checking
        lastError = nil
        updater.check(success: { [weak self, weak updater] in
            Task { @MainActor in
                self?.status = .installing(version: self?.currentStatusVersion ?? "latest")
            }
            updater?.install()
        }, fail: { [weak self] error in
            self?.handleCheckFailure(error)
        })
    }

    private func handleCheckFailure(_ error: Error) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        if error.isCancelled {
            return
        }

        lastError = error
        if case AppUpdater.Error.noValidUpdate = error {
            status = .upToDate
        } else {
            status = .failed(message: error.localizedDescription)
        }
    }

    private var currentStatusVersion: String {
        switch status {
        case .updateAvailable(let version),
                .downloading(let version, _),
                .downloaded(let version),
                .installing(let version):
            return version
        case .idle, .checking, .upToDate, .failed:
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "latest"
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String)
    case downloading(version: String, fraction: Double)
    case downloaded(version: String)
    case installing(version: String)
    case failed(message: String)

    init(state: AppUpdater.UpdateState) {
        switch state {
        case .none:
            self = .idle
        case .newVersionDetected(let release, _):
            self = .updateAvailable(version: UpdateStatus.formatVersion(release.tagName))
        case .downloading(let release, _, let fraction):
            self = .downloading(version: UpdateStatus.formatVersion(release.tagName), fraction: fraction)
        case .downloaded(let release, _, _):
            self = .downloaded(version: UpdateStatus.formatVersion(release.tagName))
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Updates"
        case .checking:
            return "Checking for updates"
        case .upToDate:
            return "Up to date"
        case .updateAvailable(let version):
            return "Update available \(version)"
        case .downloading(let version, _):
            return "Downloading \(version)"
        case .downloaded(let version):
            return "Downloaded \(version)"
        case .installing(let version):
            return "Installing \(version)"
        case .failed:
            return "Update failed"
        }
    }

    var subtitle: String {
        switch self {
        case .idle:
            return "Check GitHub Releases for the latest build."
        case .checking:
            return "Contacting GitHub Releases."
        case .upToDate:
            return "You are on the latest published version."
        case .updateAvailable:
            return "The release is ready to download."
        case .downloading(_, let fraction):
            return "\(Int(fraction * 100))% downloaded."
        case .downloaded:
            return "Installing the update now."
        case .installing:
            return "Relaunching Clocker."
        case .failed(let message):
            return message
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "arrow.down.circle"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .upToDate:
            return "checkmark.seal"
        case .updateAvailable:
            return "arrow.down.circle.fill"
        case .downloading:
            return "arrow.down.circle.fill"
        case .downloaded:
            return "checkmark.circle.fill"
        case .installing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .downloaded, .installing:
            return true
        case .idle, .upToDate, .updateAvailable, .failed:
            return false
        }
    }

    var progress: Double? {
        if case .downloading(_, let fraction) = self {
            return fraction
        }
        return nil
    }

    private static func formatVersion(_ version: Version) -> String {
        var result = "\(version.major).\(version.minor).\(version.patch)"
        if !version.prereleaseIdentifiers.isEmpty {
            result += "-" + version.prereleaseIdentifiers.joined(separator: ".")
        }
        if !version.buildMetadataIdentifiers.isEmpty {
            result += "+" + version.buildMetadataIdentifiers.joined(separator: ".")
        }
        return result
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
