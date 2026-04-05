import Foundation
import SwiftData

@MainActor
protocol ProjectRepository: AnyObject {
    func loadProjects() -> [ClockProject]
    func saveProjects(_ projects: [ClockProject])
    func loadActiveProjectID(projects: [ClockProject]) -> String
    func saveActiveProjectID(_ projectID: String)
    func projectDirectoryURL(for projectID: String) -> URL
    func ensureProjectDirectoryExists(for projectID: String)
    func ensureStorageDirectoryExists()
}

@Model
final class StoredProject {
    @Attribute(.unique) var id: String
    var name: String
    var lastUsedAt: Date?
    var sortOrder: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        lastUsedAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.lastUsedAt = lastUsedAt
        self.sortOrder = sortOrder
    }

    func asClockProject() -> ClockProject {
        ClockProject(id: id, name: name, lastUsedAt: lastUsedAt)
    }
}

@Model
final class StoredAppState {
    static let defaultKey = "app-state"

    @Attribute(.unique) var key: String
    var activeProjectID: String

    init(
        key: String = StoredAppState.defaultKey,
        activeProjectID: String = ClockProject.defaultID
    ) {
        self.key = key
        self.activeProjectID = activeProjectID
    }
}

@MainActor
final class ProjectStore: ProjectRepository {
    private struct LegacyAppState: Codable {
        var activeProjectID: String
    }

    private let legacyStorageURL: URL
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(legacyStorageURL: URL, modelContainer: ModelContainer) {
        self.legacyStorageURL = legacyStorageURL
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        importLegacyDataIfNeeded()
    }

    func loadProjects() -> [ClockProject] {
        let storedProjects = fetchStoredProjects()
        guard !storedProjects.isEmpty else {
            return [ClockProject.defaultProject]
        }

        let projects = storedProjects.map { $0.asClockProject() }
        if projects.contains(where: { $0.id == ClockProject.defaultID }) {
            return projects
        }

        return [ClockProject.defaultProject] + projects
    }

    func saveProjects(_ projects: [ClockProject]) {
        ensureStorageDirectoryExists()

        let existingProjects = fetchStoredProjects()
        existingProjects.forEach { modelContext.delete($0) }

        for (index, project) in projects.enumerated() {
            modelContext.insert(
                StoredProject(
                    id: project.id,
                    name: project.name,
                    lastUsedAt: project.lastUsedAt,
                    sortOrder: index
                )
            )
        }

        try? modelContext.save()
    }

    func loadActiveProjectID(projects: [ClockProject]) -> String {
        guard let appState = fetchAppState(),
              projects.contains(where: { $0.id == appState.activeProjectID })
        else {
            return ClockProject.defaultID
        }

        return appState.activeProjectID
    }

    func saveActiveProjectID(_ projectID: String) {
        ensureStorageDirectoryExists()

        let appState = fetchOrCreateAppState()
        appState.activeProjectID = projectID
        try? modelContext.save()
    }

    func projectDirectoryURL(for projectID: String) -> URL {
        guard projectID != ClockProject.defaultID else {
            return legacyStorageURL
        }

        return legacyStorageURL.appendingPathComponent(projectID, isDirectory: true)
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
        try? FileManager.default.createDirectory(at: legacyStorageURL, withIntermediateDirectories: true)
    }

    static func makeModelContainer() -> ModelContainer {
        makeModelContainer(baseURL: ClockModel.storageURL)
    }

    static func makeModelContainer(baseURL: URL) -> ModelContainer {
        let schema = Schema([StoredProject.self, StoredAppState.self])
        let storeURL = defaultModelStoreURL(baseURL: baseURL)
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        do {
            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    private static func defaultModelStoreURL(baseURL: URL) -> URL {
        baseURL
            .appendingPathComponent(".swiftdata", isDirectory: true)
            .appendingPathComponent("ProjectStore.store")
    }

    private func importLegacyDataIfNeeded() {
        guard fetchStoredProjects().isEmpty else {
            if fetchAppState() == nil {
                modelContext.insert(StoredAppState())
                try? modelContext.save()
            }
            cleanupLegacyProjectFiles()
            return
        }

        let legacyProjects = loadLegacyProjects()
        let projectsToStore = legacyProjects.isEmpty ? [ClockProject.defaultProject] : legacyProjects

        for (index, project) in projectsToStore.enumerated() {
            modelContext.insert(
                StoredProject(
                    id: project.id,
                    name: project.name,
                    lastUsedAt: project.lastUsedAt,
                    sortOrder: index
                )
            )
        }

        modelContext.insert(StoredAppState(activeProjectID: loadLegacyActiveProjectID(validProjectIDs: Set(projectsToStore.map(\.id)))))
        try? modelContext.save()
        cleanupLegacyProjectFiles()
    }

    private func fetchStoredProjects() -> [StoredProject] {
        let descriptor = FetchDescriptor<StoredProject>()
        let projects = (try? modelContext.fetch(descriptor)) ?? []
        return projects.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func fetchAppState() -> StoredAppState? {
        let descriptor = FetchDescriptor<StoredAppState>()
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchOrCreateAppState() -> StoredAppState {
        if let appState = fetchAppState() {
            return appState
        }

        let appState = StoredAppState()
        modelContext.insert(appState)
        return appState
    }

    private func loadLegacyProjects() -> [ClockProject] {
        let projectsFileURL = legacyStorageURL.appendingPathComponent("projects.json")
        guard let data = try? Data(contentsOf: projectsFileURL),
              let decoded = try? JSONDecoder().decode([ClockProject].self, from: data),
              !decoded.isEmpty
        else {
            return []
        }

        if decoded.contains(where: { $0.id == ClockProject.defaultID }) {
            return decoded
        }

        return [ClockProject.defaultProject] + decoded
    }

    private func loadLegacyActiveProjectID(validProjectIDs: Set<String>) -> String {
        let stateFileURL = legacyStorageURL.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode(LegacyAppState.self, from: data),
              validProjectIDs.contains(decoded.activeProjectID)
        else {
            return ClockProject.defaultID
        }

        return decoded.activeProjectID
    }

    private func cleanupLegacyProjectFiles() {
        let fileNames = ["projects.json", "state.json"]
        for fileName in fileNames {
            let url = legacyStorageURL.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
