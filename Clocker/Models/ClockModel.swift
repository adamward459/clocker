import SwiftUI
import Combine

@MainActor
final class ClockModel: ObservableObject, @unchecked Sendable {
    nonisolated static let sessionSeparator = "---"

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

    nonisolated static func storageFolderName(bundleIdentifier: String?) -> String {
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

    var resolvedStorageURL: URL { storageURL }
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
    private let projectStore: any ProjectRepository
    private let storageURL: URL
    private var elapsedSeconds: Int = 0
    private var projectElapsedSeconds: [String: Int] = [:]
    private var trackingDate: String

    init(projectRepository: any ProjectRepository, timeWriter: TimeWriter) {
        self.projectStore = projectRepository
        self.timeWriter = timeWriter
        self.storageURL = timeWriter.storageURL
        self.trackingDate = Self.todayString()
        let loadedProjects = projectRepository.loadProjects()
        self.projects = loadedProjects
        self.activeProjectID = projectRepository.loadActiveProjectID(projects: loadedProjects)
        projectRepository.saveProjects(loadedProjects)
        projectRepository.saveActiveProjectID(activeProjectID)
        bootstrapLiveSessionState()
    }

    func restoreTodayRecordIfAvailable() {
        guard timer == nil else { return }
        bootstrapLiveSessionState()
    }

    func start() {
        guard !isRunning else { return }
        handleDayChangeIfNeeded()
        restoreState = .idle
        isRunning = true
        onRunningStateChange?(true)
        persistLiveSessionState()
        beginRunningTimer()
    }

    func startNewSession() {
        guard !isRunning else { return }
        handleDayChangeIfNeeded()

        let currentDayURL = Self.currentDayFileURL(storageURL: resolvedStorageURL, projectID: activeProjectID)
        if FileManager.default.fileExists(atPath: currentDayURL.path) {
            timeWriter.beginNewSession(projectID: activeProjectID)
        }

        elapsedSeconds = 0
        projectElapsedSeconds[activeProjectID] = 0
        trackingDate = Self.todayString()
        displayTime = Self.formatElapsed(0)
        onTimeChange?(displayTime)
        restoreState = .idle

        isRunning = true
        onRunningStateChange?(true)
        persistLiveSessionState()
        beginRunningTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        onRunningStateChange?(false)
        persistLiveSessionState()
    }

    func reset() {
        stop()
        timeWriter.clearTodayRecord(projectID: activeProjectID)
        elapsedSeconds = 0
        projectElapsedSeconds[activeProjectID] = 0
        trackingDate = Self.todayString()
        displayTime = "00:00"
        onTimeChange?(displayTime)
        onRunningStateChange?(false)
        persistLiveSessionState()
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
        persistLiveSessionState()

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

    nonisolated static func currentDayFileURL(storageURL: URL, projectID: String = ClockProject.defaultID, date: Date = Date()) -> URL {
        let directoryURL = projectID == ClockProject.defaultID ? storageURL : storageURL.appendingPathComponent(projectID, isDirectory: true)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let fileName = fmt.string(from: date) + ".txt"
        return directoryURL.appendingPathComponent(fileName)
    }

    nonisolated static func parseElapsedSeconds(from contents: String) -> Int? {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        if lines.last == Self.sessionSeparator {
            return 0
        }

        return parseSessionDurations(from: contents).last
    }

    nonisolated static func parseSessionDurations(from contents: String) -> [Int] {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        var sessions: [[String]] = [[]]
        for line in lines {
            if line == Self.sessionSeparator {
                sessions.append([])
            } else {
                sessions[sessions.count - 1].append(line)
            }
        }

        return sessions.compactMap { sessionLines in
            guard let lastLine = sessionLines.last else { return nil }
            return parseTimeString(lastLine)
        }
    }

    nonisolated static func parseTimeString(_ value: String) -> Int? {
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

    nonisolated static func formatElapsed(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func handleDayChangeIfNeeded() {
        let today = Self.todayString()
        guard today != trackingDate else { return }
        trackingDate = today
        elapsedSeconds = 0
        projectElapsedSeconds[activeProjectID] = 0
        displayTime = Self.formatElapsed(0)
        onTimeChange?(displayTime)
        persistLiveSessionState()
    }

    nonisolated static func todayString(date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func loadElapsedSeconds(for projectID: String) -> Int? {
        let url = Self.currentDayFileURL(storageURL: resolvedStorageURL, projectID: projectID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return Self.parseElapsedSeconds(from: contents)
    }

    private func loadRestorableElapsedSeconds(for projectID: String) -> Int? {
        let url = Self.currentDayFileURL(storageURL: resolvedStorageURL, projectID: projectID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let sessionDurations = Self.parseSessionDurations(from: contents)
        guard let restoredSeconds = Self.parseElapsedSeconds(from: contents),
              restoredSeconds > 0 || !sessionDurations.isEmpty
        else {
            return nil
        }

        return restoredSeconds
    }

    private func markActiveProjectUsed() {
        markProjectUsed(activeProjectID)
    }

    private func markProjectUsed(_ projectID: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].lastUsedAt = Date()
        projectStore.saveProjects(projects)
    }

    private func beginRunningTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.handleDayChangeIfNeeded()
                self.elapsedSeconds += 1
                self.projectElapsedSeconds[self.activeProjectID] = self.elapsedSeconds
                let formatted = Self.formatElapsed(self.elapsedSeconds)
                self.displayTime = formatted
                self.onTimeChange?(formatted)
                self.timeWriter.persist(formatted, projectID: self.activeProjectID)
                self.persistLiveSessionState()
            }
    }

    private func bootstrapLiveSessionState() {
        let today = Self.todayString()
        let loadedSession = projectStore.loadLiveSessionState()
        let activeProjectFromStore = projectStore.loadActiveProjectID(projects: projects)
        let sessionProjectID = loadedSession.flatMap { session -> String? in
            guard session.trackingDate == today,
                  projects.contains(where: { $0.id == session.activeProjectID }) else { return nil }
            return session.activeProjectID
        }
        let restoredProjectID = sessionProjectID ?? (projects.contains(where: { $0.id == activeProjectFromStore }) ? activeProjectFromStore : ClockProject.defaultID)

        activeProjectID = restoredProjectID
        trackingDate = today

        var restoredSeconds = 0
        var restoredIsRunning = false
        var restoreStateValue: RestoreState = .unavailable

        if let session = loadedSession,
           session.trackingDate == today,
           projects.contains(where: { $0.id == session.activeProjectID }) {
            restoredSeconds = session.elapsedSeconds
            restoredIsRunning = session.isRunning
            restoreStateValue = session.isRunning || session.elapsedSeconds > 0 ? .restored : .idle
            if !restoredIsRunning, restoredSeconds == 0, let fileSeconds = loadRestorableElapsedSeconds(for: restoredProjectID) {
                restoredSeconds = fileSeconds
                restoreStateValue = .restored
            }
        } else if let fileSeconds = loadRestorableElapsedSeconds(for: restoredProjectID) {
            restoredSeconds = fileSeconds
            restoreStateValue = .restored
        }

        elapsedSeconds = restoredSeconds
        projectElapsedSeconds[restoredProjectID] = restoredSeconds
        isRunning = restoredIsRunning
        displayTime = Self.formatElapsed(restoredSeconds)
        restoreState = restoreStateValue
        onTimeChange?(displayTime)
        onRunningStateChange?(isRunning)

        projectStore.saveActiveProjectID(restoredProjectID)
        persistLiveSessionState()

        if isRunning {
            beginRunningTimer()
        }
    }

    private func persistLiveSessionState() {
        projectStore.saveLiveSessionState(
            ClockSessionState(
                activeProjectID: activeProjectID,
                elapsedSeconds: elapsedSeconds,
                trackingDate: trackingDate,
                isRunning: isRunning
            )
        )
    }
}
