import Foundation

struct ClockRestorationResult {
    let projects: [Project]
    let selectedProject: Project
    let session: Session?
    let isRunning: Bool
    let displayTime: String
    let restoreState: ClockService.RestoreState
    let trackingDate: String
}

@MainActor
final class ClockStateRestorer {
    private let projectSessionService: ProjectSessionService
    private let appStateService: AppStateService

    init(projectSessionService: ProjectSessionService, appStateService: AppStateService) {
        self.projectSessionService = projectSessionService
        self.appStateService = appStateService
    }

    func restore() -> ClockRestorationResult {
        var loadedProjects = projectSessionService.loadProjects()
        if loadedProjects.isEmpty {
            _ = projectSessionService.createProject(named: Project.defaultName)
            loadedProjects = projectSessionService.loadProjects()
        }

        guard let firstProject = loadedProjects.first else {
            let fallback = Project(name: Project.defaultName)
            return ClockRestorationResult(
                projects: [fallback],
                selectedProject: fallback,
                session: nil,
                isRunning: false,
                displayTime: "00:00",
                restoreState: .unavailable,
                trackingDate: ClockService.todayString()
            )
        }

        let appState = appStateService.loadAppState()
        let selectedProject = appState?.selectedProject ?? firstProject
        let trackingDate = ClockService.todayString()
        let session = restoredSession(for: selectedProject.id, today: trackingDate, appState: appState)
        let elapsedSeconds = session?.currentElapsedSeconds ?? 0
        let isRunning = session?.isRunning ?? false
        let restoreState: ClockService.RestoreState = session == nil ? .unavailable : ((isRunning || elapsedSeconds > 0) ? .restored : .idle)

        return ClockRestorationResult(
            projects: loadedProjects,
            selectedProject: selectedProject,
            session: session,
            isRunning: isRunning,
            displayTime: ClockService.formatElapsed(elapsedSeconds),
            restoreState: restoreState,
            trackingDate: trackingDate
        )
    }

    private func restoredSession(for projectID: UUID, today: String, appState: AppState?) -> Session? {
        if let currentSession = appState?.currentSession,
           currentSession.projectId == projectID,
           currentSession.dateKey == today,
           currentSession.status != .undone {
            return normalizedRestoredSession(currentSession)
        }

        guard let latestSession = projectSessionService.loadLatestSession(for: projectID, dateKey: today) else {
            return nil
        }

        guard latestSession.status != .undone else {
            return nil
        }

        return normalizedRestoredSession(latestSession)
    }

    private func normalizedRestoredSession(_ session: Session) -> Session {
        guard session.status == .running else {
            return session
        }

        session.pauseRunning()
        projectSessionService.saveSession(session)
        return session
    }
}
