import Foundation

final class ProjectStore {
    private struct AppState: Codable {
        var activeProjectID: String
    }

    private let storageURL: URL
    private let projectsFileURL: URL
    private let stateFileURL: URL

    init(storageURL: URL) {
        self.storageURL = storageURL
        self.projectsFileURL = storageURL.appendingPathComponent("projects.json")
        self.stateFileURL = storageURL.appendingPathComponent("state.json")
    }

    func loadProjects() -> [ClockProject] {
        guard let data = try? Data(contentsOf: projectsFileURL),
              let decoded = try? JSONDecoder().decode([ClockProject].self, from: data)
        else {
            return [ClockProject.defaultProject]
        }

        guard !decoded.isEmpty else {
            return [ClockProject.defaultProject]
        }

        if decoded.contains(where: { $0.id == ClockProject.defaultID }) {
            return decoded
        }

        return [ClockProject.defaultProject] + decoded
    }

    func saveProjects(_ projects: [ClockProject]) {
        ensureStorageDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: projectsFileURL, options: [.atomic])
    }

    func loadActiveProjectID(projects: [ClockProject]) -> String {
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode(AppState.self, from: data),
              projects.contains(where: { $0.id == decoded.activeProjectID })
        else {
            return ClockProject.defaultID
        }

        return decoded.activeProjectID
    }

    func saveActiveProjectID(_ projectID: String) {
        ensureStorageDirectoryExists()

        let state = AppState(activeProjectID: projectID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateFileURL, options: [.atomic])
    }

    func projectDirectoryURL(for projectID: String) -> URL {
        guard projectID != ClockProject.defaultID else {
            return storageURL
        }

        return storageURL.appendingPathComponent(projectID, isDirectory: true)
    }

    func ensureProjectDirectoryExists(for projectID: String) {
        guard projectID != ClockProject.defaultID else {
            ensureStorageDirectoryExists()
            return
        }

        let projectURL = projectDirectoryURL(for: projectID)
        try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    }

    func ensureStorageDirectoryExists() {
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
}
