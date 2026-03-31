import SwiftUI
import Combine

final class ClockModel: ObservableObject, @unchecked Sendable {
    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored
        case unavailable
    }

    @Published var displayTime: String = "00:00"
    @Published var isRunning: Bool = false
    @Published var restoreState: RestoreState = .idle
    @Published private(set) var projects: [ClockProject] = []
    @Published private(set) var activeProjectID: String = ClockProject.defaultID
    var onTimeChange: ((String) -> Void)?
    var onRunningStateChange: ((Bool) -> Void)?

    static var storageFolderName: String {
        storageFolderName(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static func storageFolderName(bundleIdentifier: String?) -> String {
        if bundleIdentifier?.contains(".dev") == true {
            return "Clocker-Dev"
        }

        #if DEBUG
        return "Clocker-Dev"
        #else
        return "Clocker"
        #endif
    }

    static var storageURL: URL {
        let documents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documents.appendingPathComponent(storageFolderName, isDirectory: true)
    }

    var resolvedStorageURL: URL { Self.storageURL }
    var activeProject: ClockProject {
        projects.first(where: { $0.id == activeProjectID }) ?? .defaultProject
    }
    var activeProjectName: String { activeProject.name }
    var orderedProjects: [ClockProject] {
        projects.sorted { lhs, rhs in
            if lhs.id == activeProjectID { return true }
            if rhs.id == activeProjectID { return false }

            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (left?, right?):
                if left != right {
                    return left > right
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    var menuBarTitle: String {
        let title = activeProjectName.count > 8 ? String(activeProjectName.prefix(8)) + "…" : activeProjectName
        return " \(title) \(displayTime)"
    }

    private var timer: AnyCancellable?
    private let timeWriter: TimeWriter
    private let projectStore: ProjectStore
    private var elapsedSeconds: Int = 0
    private var projectElapsedSeconds: [String: Int] = [:]
    private var restoreFeedbackWorkItem: DispatchWorkItem?

    convenience init() {
        self.init(
            projectStore: ProjectStore(storageURL: Self.storageURL),
            timeWriter: TimeWriter(storageURL: Self.storageURL)
        )
    }

    convenience init(timeWriter: TimeWriter) {
        self.init(
            projectStore: ProjectStore(storageURL: timeWriter.storageURL),
            timeWriter: timeWriter
        )
    }

    init(projectStore: ProjectStore, timeWriter: TimeWriter) {
        self.projectStore = projectStore
        self.timeWriter = timeWriter
        let loadedProjects = projectStore.loadProjects()
        self.projects = loadedProjects
        self.activeProjectID = projectStore.loadActiveProjectID(projects: loadedProjects)

        if !loadedProjects.contains(where: { $0.id == activeProjectID }) {
            activeProjectID = ClockProject.defaultID
        }

        projectStore.saveProjects(loadedProjects)
        projectStore.saveActiveProjectID(activeProjectID)
    }

    func restoreTodayRecordIfAvailable() {
        guard !isRunning else { return }

        let url = Self.currentDayFileURL(storageURL: resolvedStorageURL, projectID: activeProjectID)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            restoreState = .unavailable
            return
        }

        restoreFeedbackWorkItem?.cancel()
        let feedbackWorkItem = DispatchWorkItem { [weak self] in
            self?.restoreState = .restoring
        }
        restoreFeedbackWorkItem = feedbackWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: feedbackWorkItem)

        DispatchQueue.global(qos: .utility).async { [url, weak self] in
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let restoredSeconds = Self.parseElapsedSeconds(from: contents)

            DispatchQueue.main.async {
                guard let self else { return }
                self.restoreFeedbackWorkItem?.cancel()
                self.restoreFeedbackWorkItem = nil

                guard let restoredSeconds else {
                    self.restoreState = .unavailable
                    return
                }

                self.elapsedSeconds = restoredSeconds
                self.projectElapsedSeconds[self.activeProjectID] = restoredSeconds
                self.displayTime = Self.formatElapsed(restoredSeconds)
                self.onTimeChange?(self.displayTime)
                self.markActiveProjectUsed()
                self.restoreState = .restored
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        onRunningStateChange?(true)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                self.projectElapsedSeconds[self.activeProjectID] = self.elapsedSeconds
                let formatted = Self.formatElapsed(self.elapsedSeconds)
                self.displayTime = formatted
                self.onTimeChange?(formatted)
                self.timeWriter.persist(formatted, projectID: self.activeProjectID)
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        onRunningStateChange?(false)
    }

    func reset() {
        stop()
        timeWriter.clearTodayRecord(projectID: activeProjectID)
        elapsedSeconds = 0
        projectElapsedSeconds[activeProjectID] = 0
        displayTime = "00:00"
        onTimeChange?(displayTime)
        onRunningStateChange?(false)
    }

    func switchToProject(_ projectID: String) {
        guard projects.contains(where: { $0.id == projectID }) else { return }
        guard projectID != activeProjectID else { return }

        let shouldResume = isRunning
        if shouldResume {
            timer?.cancel()
            timer = nil
            isRunning = false
            onRunningStateChange?(false)
        }

        projectElapsedSeconds[activeProjectID] = elapsedSeconds
        activeProjectID = projectID
        projectStore.saveActiveProjectID(projectID)
        restoreState = .idle

        let restoredSeconds = projectElapsedSeconds[projectID] ?? loadElapsedSeconds(for: projectID) ?? 0
        elapsedSeconds = restoredSeconds
        projectElapsedSeconds[projectID] = restoredSeconds
        displayTime = Self.formatElapsed(restoredSeconds)
        onTimeChange?(displayTime)
        markProjectUsed(projectID)

        if shouldResume {
            start()
        }
    }

    @discardableResult
    func createProject(named rawName: String) -> ClockProject? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let project = ClockProject(name: name)
        projects.append(project)
        projectStore.saveProjects(projects)
        switchToProject(project.id)
        return project
    }

    func projectStorageURL(for projectID: String) -> URL {
        projectStore.projectDirectoryURL(for: projectID)
    }

    func projectName(for projectID: String) -> String {
        projects.first(where: { $0.id == projectID })?.name ?? projectID
    }

    func renameProject(_ projectID: String, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].name = name
        projectStore.saveProjects(projects)
    }

    func deleteProject(_ projectID: String) {
        guard projectID != ClockProject.defaultID,
              let index = projects.firstIndex(where: { $0.id == projectID }) else { return }

        if activeProjectID == projectID {
            switchToProject(ClockProject.defaultID)
        }

        projects.remove(at: index)
        projectElapsedSeconds.removeValue(forKey: projectID)
        projectStore.saveProjects(projects)
    }

    static func currentDayFileURL(storageURL: URL, projectID: String = ClockProject.defaultID, date: Date = Date()) -> URL {
        let directoryURL = projectID == ClockProject.defaultID ? storageURL : storageURL.appendingPathComponent(projectID, isDirectory: true)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let fileName = fmt.string(from: date) + ".txt"
        return directoryURL.appendingPathComponent(fileName)
    }

    static func parseElapsedSeconds(from contents: String) -> Int? {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return nil }
        return parseTimeString(lastLine)
    }

    static func parseTimeString(_ value: String) -> Int? {
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        if numbers.count == 2 {
            return numbers[0] * 60 + numbers[1]
        } else {
            return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        }
    }

    static func formatElapsed(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func loadElapsedSeconds(for projectID: String) -> Int? {
        let url = Self.currentDayFileURL(storageURL: resolvedStorageURL, projectID: projectID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return Self.parseElapsedSeconds(from: contents)
    }

    private func markActiveProjectUsed() {
        markProjectUsed(activeProjectID)
    }

    private func markProjectUsed(_ projectID: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].lastUsedAt = Date()
        projectStore.saveProjects(projects)
    }
}
