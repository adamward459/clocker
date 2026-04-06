import Foundation
import SwiftData

@MainActor
final class ProjectSessionService {
    private let repository: ProjectSessionRepository

    init(repository: ProjectSessionRepository) {
        self.repository = repository
    }

    convenience init(modelContainer: ModelContainer) {
        self.init(repository: SwiftDataProjectSessionRepository(modelContainer: modelContainer))
    }

    func loadProjects() -> [Project] {
        repository.loadProjects()
    }

    func loadProject(id: UUID) -> Project? {
        repository.loadProject(id: id)
    }

    func createProject(named rawName: String) -> Project? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let project = Project(name: name, lastUsedAt: .now)
        repository.saveProject(project)
        return project
    }

    func renameProject(_ projectId: UUID, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let project = repository.loadProject(id: projectId) else { return }

        project.name = name
        repository.saveProject(project)
    }

    func deleteProject(_ projectId: UUID) {
        repository.deleteProject(id: projectId)
    }

    func markProjectUsed(_ projectId: UUID, at date: Date = .now) {
        guard let project = repository.loadProject(id: projectId) else { return }
        project.lastUsedAt = date
        repository.saveProject(project)
    }

    func loadSessions() -> [Session] {
        repository.loadSessions()
    }

    func loadSessions(for projectId: UUID) -> [Session] {
        repository.loadSessions(for: projectId)
    }

    func loadLatestSession(for projectId: UUID, dateKey: String) -> Session? {
        loadSessions(for: projectId)
            .filter { $0.dateKey == dateKey }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .last
    }

    func createSession(
        for projectId: UUID,
        dateKey: String = ClockService.todayString(),
        elapsedSeconds: Int = 0,
        startedAt: Date? = nil,
        status: Session.Status = .done,
        createdAt: Date = .now
    ) -> Session? {
        guard let project = repository.loadProject(id: projectId) else { return nil }

        let session = Session(
            projectId: projectId,
            project: project,
            dateKey: dateKey,
            elapsedSeconds: elapsedSeconds,
            startedAt: startedAt,
            status: status,
            createdAt: createdAt
        )
        repository.saveSession(session)
        return session
    }

    func loadSession(id: UUID) -> Session? {
        repository.loadSession(id: id)
    }

    func saveSession(_ session: Session) {
        repository.saveSession(session)
    }

    func startSession(_ session: Session, at date: Date = .now) {
        session.startRunning(at: date)
        repository.saveSession(session)
    }

    func pauseSession(_ session: Session, at date: Date = .now) {
        session.pauseRunning(at: date)
        repository.saveSession(session)
    }

    func deleteSession(_ sessionId: UUID) {
        repository.deleteSession(id: sessionId)
    }

    func deleteSessions(for projectId: UUID, dateKey: String) {
        loadSessions(for: projectId)
            .filter { $0.dateKey == dateKey }
            .forEach { repository.deleteSession(id: $0.id) }
    }
}
