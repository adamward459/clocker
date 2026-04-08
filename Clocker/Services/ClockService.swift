import Combine
import Foundation
import SwiftUI

@MainActor
final class ClockService: ObservableObject, @unchecked Sendable {
    nonisolated static let sessionSeparator = "---"

    static var storageURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return documentsDirectory
            .appendingPathComponent(storageFolderName(bundleIdentifier: Bundle.main.bundleIdentifier), isDirectory: true)
    }

    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored
        case unavailable
    }

    @Published private(set) var state = ClockState()

    var onTimeChange: ((String) -> Void)?
    var onRunningStateChange: ((Bool) -> Void)?

    let projectSessionService: ProjectSessionService
    let appStateService: AppStateService

    private let stateRestorer: ClockStateRestorer
    private lazy var timerDriver = ClockTimerDriver(onTick: { [weak self] in
        self?.tick()
    })

    init(projectSessionService: ProjectSessionService, appStateService: AppStateService) {
        self.projectSessionService = projectSessionService
        self.appStateService = appStateService
        self.stateRestorer = ClockStateRestorer(
            projectSessionService: projectSessionService,
            appStateService: appStateService
        )
        apply(stateRestorer.restore())
    }

    var displayTime: String { state.displayTime }
    var isRunning: Bool { state.isRunning }
    var restoreState: RestoreState { state.restoreState }
    var projects: [Project] { state.projects }
    var activeProjectID: UUID { state.activeProjectID }
    var dataRevision: UUID { state.dataRevision }
    var activeSession: Session? { state.activeSession }
    var trackingDate: String { state.trackingDate }

    var activeProject: Project {
        state.projects.first(where: { $0.id == state.activeProjectID }) ?? state.projects.first ?? Project(name: Project.defaultName)
    }

    var activeProjectName: String {
        activeProject.name
    }

    var orderedProjects: [Project] {
        state.projects.sorted { lhs, rhs in
            if lhs.id == state.activeProjectID { return true }
            if rhs.id == state.activeProjectID { return false }

            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (left?, right?):
                if left != right { return left > right }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var menuBarTitle: String {
        let title = activeProjectName.count > 8 ? String(activeProjectName.prefix(8)) + "…" : activeProjectName
        return " \(title) \(displayTime)"
    }

    var resolvedStorageURL: URL { Self.storageURL }

    func restoreTodayRecordIfAvailable() -> ClockRestorationResult {
        let result = stateRestorer.restore()
        apply(result)
        return result
    }

    @discardableResult
    func start() -> Session? {
        guard !isRunning else { return nil }
        handleDayChangeIfNeeded()

        let today = Self.todayString()
        if state.activeSession == nil
            || state.activeSession?.projectId != state.activeProjectID
            || state.activeSession?.dateKey != today
            || state.activeSession?.status == .undone
        {
            state.activeSession = projectSessionService.loadLatestSession(for: state.activeProjectID, dateKey: today)
        }

        if state.activeSession == nil {
            state.activeSession = projectSessionService.createSession(
                for: state.activeProjectID,
                dateKey: today,
                elapsedSeconds: 0,
                startedAt: nil,
                status: .done
            )
        }

        guard let activeSession = state.activeSession else { return nil }

        projectSessionService.startSession(activeSession)
        appStateService.setCurrentSession(activeSession)
        projectSessionService.markProjectUsed(state.activeProjectID)

        state.isRunning = true
        state.restoreState = .idle
        state.displayTime = Self.formatElapsed(activeSession.currentElapsedSeconds)
        onTimeChange?(state.displayTime)
        onRunningStateChange?(true)
        bumpDataRevision()
        timerDriver.beginRunningTimer()
        return activeSession
    }

    @discardableResult
    func startNewSession() -> Session? {
        guard !isRunning else { return nil }
        handleDayChangeIfNeeded()

        let today = Self.todayString()
        state.activeSession = projectSessionService.createSession(
            for: state.activeProjectID,
            dateKey: today,
            elapsedSeconds: 0,
            startedAt: nil,
            status: .done
        )
        bumpDataRevision()
        return start()
    }

    @discardableResult
    func stop() -> Session? {
        guard isRunning else { return nil }
        timerDriver.stopMonitoring()

        if let activeSession = state.activeSession {
            projectSessionService.pauseSession(activeSession)
            appStateService.setCurrentSession(activeSession)
            state.displayTime = Self.formatElapsed(activeSession.currentElapsedSeconds)
            onTimeChange?(state.displayTime)
        }

        state.isRunning = false
        onRunningStateChange?(false)
        bumpDataRevision()
        return state.activeSession
    }

    @discardableResult
    func reset() -> Session? {
        _ = stop()
        projectSessionService.deleteSessions(for: state.activeProjectID, dateKey: state.trackingDate)
        state.activeSession = nil
        appStateService.clearCurrentSession()
        state.restoreState = .idle
        state.displayTime = "00:00"
        onTimeChange?(state.displayTime)
        bumpDataRevision()
        return nil
    }

    @discardableResult
    func switchToProject(_ projectID: UUID) -> Session? {
        guard state.projects.contains(where: { $0.id == projectID }) else { return nil }
        guard projectID != state.activeProjectID else { return state.activeSession }

        let shouldResume = isRunning
        if shouldResume {
            _ = stop()
        }

        state.activeProjectID = projectID
        if let project = projectSessionService.loadProject(id: projectID) {
            appStateService.setSelectedProject(project)
            projectSessionService.markProjectUsed(projectID)
        }

        refreshStateForSelectedProject()

        if shouldResume {
            return start()
        } else {
            return state.activeSession
        }
    }

    func createProject(named rawName: String) -> Project? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        guard let project = projectSessionService.createProject(named: name) else { return nil }
        refreshProjects()
        _ = switchToProject(project.id)
        bumpDataRevision()
        return project
    }

    func projectName(for projectID: UUID) -> String {
        state.projects.first(where: { $0.id == projectID })?.name ?? projectID.uuidString
    }

    func sessions(for projectID: UUID) -> [Session] {
        projectSessionService.loadSessions(for: projectID)
    }

    func updateHistorySessionsStatus(_ sessions: [Session], to status: Session.Status) {
        let uniqueSessions = Array(Dictionary(grouping: sessions, by: \.id).values.compactMap { $0.first })
        guard !uniqueSessions.isEmpty else { return }

        let activeSessionID = state.activeSession?.id
        let activeSessionWasUpdated = uniqueSessions.contains(where: { $0.id == activeSessionID })
        let needsStop = isRunning && activeSessionWasUpdated
        if needsStop {
            _ = stop()
        }

        for session in uniqueSessions {
            switch status {
            case .done:
                session.markDone()
            case .undone:
                session.markUndone()
            case .paused:
                continue
            case .running:
                continue
            }

            projectSessionService.saveSession(session)

            if session.id == activeSessionID {
                appStateService.setCurrentSession(session)
                state.activeSession = session
                state.isRunning = false
                state.restoreState = .idle
                state.displayTime = Self.formatElapsed(session.currentElapsedSeconds)
                onTimeChange?(state.displayTime)
                onRunningStateChange?(false)
            }
        }

        bumpDataRevision()
    }

    func renameProject(_ projectID: UUID, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        projectSessionService.renameProject(projectID, to: name)
        refreshProjects()
        bumpDataRevision()
    }

    func deleteProject(_ projectID: UUID) {
        guard state.projects.count > 1 else { return }
        guard let project = projectSessionService.loadProject(id: projectID) else { return }

        let wasActive = projectID == state.activeProjectID
        if wasActive {
            _ = stop()
        }

        projectSessionService.deleteProject(projectID)
        refreshProjects()

        if wasActive, let fallback = state.projects.first {
            state.activeProjectID = fallback.id
            appStateService.setSelectedProject(fallback)
            refreshStateForSelectedProject()
        }

        if project.id == state.activeSession?.projectId {
            state.activeSession = nil
        }

        bumpDataRevision()
    }

    func tick() {
        handleDayChangeIfNeeded()
        refreshDisplayedElapsedTime()
    }

    func apply(_ result: ClockRestorationResult) {
        state.projects = result.projects
        state.activeProjectID = result.selectedProject.id
        state.activeSession = result.session
        state.isRunning = result.isRunning
        state.displayTime = result.displayTime
        state.restoreState = result.restoreState
        state.trackingDate = result.trackingDate

        appStateService.setSelectedProject(result.selectedProject)
        if let session = result.session {
            appStateService.setCurrentSession(session)
        } else {
            appStateService.clearCurrentSession()
        }

        projectSessionService.markProjectUsed(result.selectedProject.id)

        onTimeChange?(state.displayTime)
        onRunningStateChange?(state.isRunning)
        if state.isRunning {
            timerDriver.beginRunningTimer()
        } else {
            timerDriver.stopMonitoring()
        }
        bumpDataRevision()
    }

    private func refreshProjects() {
        state.projects = projectSessionService.loadProjects()
        if state.projects.isEmpty {
            _ = projectSessionService.createProject(named: Project.defaultName)
            state.projects = projectSessionService.loadProjects()
        }
    }

    private func refreshStateForSelectedProject() {
        let today = Self.todayString()
        state.trackingDate = today
        let session = latestRestorableSession(for: state.activeProjectID, dateKey: today)
        let selectedProject = state.projects.first(where: { $0.id == state.activeProjectID }) ?? state.projects.first ?? Project(name: Project.defaultName)
        apply(makeRestorationResult(selectedProject: selectedProject, session: session))
    }

    private func latestRestorableSession(for projectID: UUID, dateKey: String) -> Session? {
        guard let session = projectSessionService.loadLatestSession(for: projectID, dateKey: dateKey) else {
            return nil
        }

        guard session.status != .undone else {
            return nil
        }

        return normalizedRestoredSession(session)
    }

    private func handleDayChangeIfNeeded() {
        let today = Self.todayString()
        guard today != state.trackingDate else { return }

        state.trackingDate = today

        if state.isRunning, let currentSession = state.activeSession {
            projectSessionService.pauseSession(currentSession)
            state.activeSession = projectSessionService.createSession(
                for: state.activeProjectID,
                dateKey: today,
                elapsedSeconds: 0,
                startedAt: .now,
                status: .running
            )
            if let currentSession = state.activeSession {
                appStateService.setCurrentSession(currentSession)
            }
            state.isRunning = true
            state.restoreState = .idle
            onRunningStateChange?(true)
            state.displayTime = "00:00"
            onTimeChange?(state.displayTime)
            timerDriver.beginRunningTimer()
            return
        }

        timerDriver.stopMonitoring()
        state.activeSession = nil
        appStateService.clearCurrentSession()
        state.displayTime = "00:00"
        onTimeChange?(state.displayTime)
        state.restoreState = .idle
        bumpDataRevision()
    }

    private func refreshDisplayedElapsedTime() {
        guard let activeSession = state.activeSession else { return }
        let formatted = Self.formatElapsed(activeSession.currentElapsedSeconds)
        state.displayTime = formatted
        onTimeChange?(formatted)
    }

    private func bumpDataRevision() {
        state.dataRevision = UUID()
    }

    private func makeRestorationResult(selectedProject: Project, session: Session?) -> ClockRestorationResult {
        let restorableSession: Session?
        if let session, session.status != .undone {
            restorableSession = normalizedRestoredSession(session)
        } else {
            restorableSession = nil
        }
        let elapsedSeconds = restorableSession?.currentElapsedSeconds ?? 0
        let isRunning = restorableSession?.isRunning ?? false
        let restoreState: RestoreState = restorableSession == nil ? .unavailable : ((isRunning || elapsedSeconds > 0) ? .restored : .idle)

        return ClockRestorationResult(
            projects: state.projects,
            selectedProject: selectedProject,
            session: restorableSession,
            isRunning: isRunning,
            displayTime: Self.formatElapsed(elapsedSeconds),
            restoreState: restoreState,
            trackingDate: Self.todayString()
        )
    }

    private func normalizedRestoredSession(_ session: Session) -> Session {
        guard session.status == .running else {
            return session
        }

        session.pauseRunning()
        projectSessionService.saveSession(session)
        return session
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

    nonisolated static func currentDayFileURL(storageURL: URL, projectID: String = ClockProject.defaultID, date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = formatter.string(from: date) + ".txt"
        let directoryURL = projectID == ClockProject.defaultID ? storageURL : storageURL.appendingPathComponent(projectID, isDirectory: true)
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

    nonisolated static func todayString(date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
