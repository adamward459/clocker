import Foundation
import SwiftData

@MainActor
protocol ProjectSessionRepository: AnyObject {
    func loadProjects() -> [Project]
    func loadProject(id: UUID) -> Project?
    func saveProject(_ project: Project)
    func saveProjects(_ projects: [Project])
    func deleteProject(id: UUID)

    func loadSessions() -> [Session]
    func loadSessions(for projectId: UUID) -> [Session]
    func loadSession(id: UUID) -> Session?
    func saveSession(_ session: Session)
    func saveSessions(_ sessions: [Session])
    func deleteSession(id: UUID)
}

@MainActor
final class SwiftDataProjectSessionRepository: ProjectSessionRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    func loadProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>()
        let projects = (try? modelContext.fetch(descriptor)) ?? []
        return projects.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func loadProject(id: UUID) -> Project? {
        loadProjects().first { $0.id == id }
    }

    func saveProject(_ project: Project) {
        if let existing = loadProject(id: project.id) {
            existing.name = project.name
            existing.createdAt = project.createdAt
            existing.sessions = project.sessions
        } else {
            modelContext.insert(project)
        }

        try? modelContext.save()
    }

    func saveProjects(_ projects: [Project]) {
        projects.forEach(saveProject)
    }

    func deleteProject(id: UUID) {
        guard let project = loadProject(id: id) else { return }
        modelContext.delete(project)
        try? modelContext.save()
    }

    func loadSessions() -> [Session] {
        let descriptor = FetchDescriptor<Session>()
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.startAt < rhs.startAt
        }
    }

    func loadSessions(for projectId: UUID) -> [Session] {
        loadSessions().filter { $0.projectId == projectId }
    }

    func loadSession(id: UUID) -> Session? {
        loadSessions().first { $0.id == id }
    }

    func saveSession(_ session: Session) {
        if let existing = loadSession(id: session.id) {
            existing.projectId = session.projectId
            existing.startAt = session.startAt
            existing.endAt = session.endAt
            existing.createdAt = session.createdAt
            existing.status = session.status
        } else {
            modelContext.insert(session)
        }

        if let project = loadProject(id: session.projectId),
           !project.sessions.contains(where: { $0.id == session.id }) {
            project.sessions.append(session)
        }

        try? modelContext.save()
    }

    func saveSessions(_ sessions: [Session]) {
        sessions.forEach(saveSession)
    }

    func deleteSession(id: UUID) {
        guard let session = loadSession(id: id) else { return }
        modelContext.delete(session)
        try? modelContext.save()
    }
}
