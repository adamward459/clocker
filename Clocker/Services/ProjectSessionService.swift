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

    func createProject(named rawName: String) -> Project? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let project = Project(name: name)
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

    func loadSessions() -> [Session] {
        repository.loadSessions()
    }

    func loadSessions(for projectId: UUID) -> [Session] {
        repository.loadSessions(for: projectId)
    }

    func createSession(
        for projectId: UUID,
        startAt: Date = .now,
        endAt: Date? = nil,
        createdAt: Date = .now,
        status: Session.Status = .undone
    ) -> Session? {
        guard repository.loadProject(id: projectId) != nil else { return nil }

        let session = Session(
            projectId: projectId,
            startAt: startAt,
            endAt: endAt,
            createdAt: createdAt,
            status: status
        )
        repository.saveSession(session)
        return session
    }

    func closeSession(_ sessionId: UUID, endAt: Date = .now) {
        guard let session = repository.loadSession(id: sessionId) else { return }
        session.endAt = endAt
        session.status = .done
        repository.saveSession(session)
    }

    func deleteSession(_ sessionId: UUID) {
        repository.deleteSession(id: sessionId)
    }
}
