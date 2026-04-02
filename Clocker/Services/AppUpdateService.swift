import AppUpdater
import Combine
import Foundation

@MainActor
final class AppUpdateService: ObservableObject {
    private let updater: AppUpdater?
    private var stateObservation: AnyCancellable?
    private var isManualCheckInProgress = false

    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var lastError: Error?
    @Published var notice: UpdateNotice?

    var isAvailable: Bool {
        updater != nil
    }

    init() {
        let hasBundleVersionMetadata = {
            guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                return false
            }
            return !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

        guard hasBundleVersionMetadata else {
            updater = nil
            status = .failed(message: "App version metadata is missing.")
            notice = .missingVersionMetadata
            return
        }

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
                self?.status = .installing
                self?.isManualCheckInProgress = false
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
                self?.handleStateNotice(for: state)
            }
        }
        status = .idle
    }

    func checkForUpdates() {
        guard let updater else { return }
        status = .checking
        lastError = nil
        notice = nil
        isManualCheckInProgress = true
        updater.check(success: { [weak self, weak updater] in
            Task { @MainActor in
                self?.status = .installing
                self?.isManualCheckInProgress = false
            }
            updater?.install()
        }, fail: { [weak self] error in
            self?.handleCheckFailure(error)
        })
    }

    private func handleStateNotice(for state: AppUpdater.UpdateState) {
        guard isManualCheckInProgress else { return }

        switch state {
        case .newVersionDetected:
            notice = .updateAvailable
        case .downloaded:
            notice = .downloaded
        case .downloading, .none:
            break
        }
    }

    private func handleCheckFailure(_ error: Error) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        isManualCheckInProgress = false

        if error.isCancelled {
            return
        }

        lastError = error
        if case AppUpdater.Error.noValidUpdate = error {
            status = .upToDate
            notice = .upToDate
        } else {
            status = .failed(message: error.localizedDescription)
            notice = .failed(message: error.localizedDescription)
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable
    case downloading(fraction: Double)
    case downloaded
    case installing
    case failed(message: String)

    init(state: AppUpdater.UpdateState) {
        switch state {
        case .none:
            self = .idle
        case .newVersionDetected:
            self = .updateAvailable
        case .downloading(_, _, let fraction):
            self = .downloading(fraction: fraction)
        case .downloaded:
            self = .downloaded
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
        case .updateAvailable:
            return "Update available"
        case .downloading:
            return "Downloading update"
        case .downloaded:
            return "Downloaded"
        case .installing:
            return "Installing update"
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
        case .downloading(let fraction):
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
        if case .downloading(let fraction) = self {
            return fraction
        }
        return nil
    }
}

enum UpdateNotice: Identifiable {
    case updateAvailable
    case downloaded
    case upToDate
    case missingVersionMetadata
    case failed(message: String)

    var id: String {
        switch self {
        case .updateAvailable:
            return "updateAvailable"
        case .downloaded:
            return "downloaded"
        case .upToDate:
            return "upToDate"
        case .missingVersionMetadata:
            return "missingVersionMetadata"
        case .failed(let message):
            return "failed-\(message)"
        }
    }

    var title: String {
        switch self {
        case .updateAvailable:
            return "Update Available"
        case .downloaded:
            return "Update Downloaded"
        case .upToDate:
            return "No Updates Found"
        case .missingVersionMetadata:
            return "Updates Disabled"
        case .failed:
            return "Update Failed"
        }
    }

    var message: String {
        switch self {
        case .updateAvailable:
            return "A newer version was found and will download in the background."
        case .downloaded:
            return "The update has finished downloading and will install now."
        case .upToDate:
            return "Clocker is already on the latest published version."
        case .missingVersionMetadata:
            return "Clocker could not read its version metadata, so updates are disabled."
        case .failed(let message):
            return message
        }
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
