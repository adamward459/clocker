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
        let descriptor = FetchDescriptor<Project>(
            sortBy: [
                SortDescriptor(\Project.lastUsedAt, order: .reverse),
                SortDescriptor(\Project.createdAt, order: .forward),
                SortDescriptor(\Project.name, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadProject(id: UUID) -> Project? {
        loadProjects().first { $0.id == id }
    }

    func saveProject(_ project: Project) {
        if let existing = loadProject(id: project.id) {
            existing.name = project.name
            existing.createdAt = project.createdAt
            existing.lastUsedAt = project.lastUsedAt
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
        let descriptor = FetchDescriptor<Session>(
            sortBy: [
                SortDescriptor(\Session.dateKey, order: .forward),
                SortDescriptor(\Session.createdAt, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadSessions(for projectId: UUID) -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [
                SortDescriptor(\Session.dateKey, order: .forward),
                SortDescriptor(\Session.createdAt, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadSession(id: UUID) -> Session? {
        loadSessions().first { $0.id == id }
    }

    func saveSession(_ session: Session) {
        if let existing = loadSession(id: session.id) {
            existing.projectId = session.projectId
            existing.project = session.project ?? loadProject(id: session.projectId)
            existing.dateKey = session.dateKey
            existing.elapsedSeconds = session.elapsedSeconds
            existing.startedAt = session.startedAt
            existing.status = session.status
            existing.createdAt = session.createdAt
        } else {
            session.project = session.project ?? loadProject(id: session.projectId)
            modelContext.insert(session)
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
