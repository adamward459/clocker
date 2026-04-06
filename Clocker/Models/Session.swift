import Foundation
import SwiftData

@Model
final class Session {
    enum Status: String, Codable, CaseIterable {
        case running
        case done
        case undone
    }

    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var project: Project?
    var dateKey: String
    var elapsedSeconds: Int
    var startedAt: Date?
    var status: Status
    var createdAt: Date

    init(
        id: UUID = UUID(),
        projectId: UUID,
        project: Project? = nil,
        dateKey: String = ClockService.todayString(),
        elapsedSeconds: Int = 0,
        startedAt: Date? = nil,
        status: Status = .done,
        createdAt: Date = .now
    ) {
        self.id = id
        self.project = project
        self.projectId = project?.id ?? projectId
        self.dateKey = dateKey
        self.elapsedSeconds = elapsedSeconds
        self.startedAt = startedAt
        self.status = status
        self.createdAt = createdAt
    }

    var isRunning: Bool {
        status == .running
    }

    var currentElapsedSeconds: Int {
        if status == .running, let startedAt {
            let delta = Int(Date().timeIntervalSince(startedAt))
            return elapsedSeconds + max(delta, 0)
        }

        return elapsedSeconds
    }

    func startRunning(at date: Date = .now) {
        guard status != .running else { return }
        startedAt = date
        status = .running
    }

    func pauseRunning(at date: Date = .now) {
        guard status == .running else { return }
        if let startedAt {
            let delta = Int(date.timeIntervalSince(startedAt))
            elapsedSeconds += max(delta, 0)
        }
        startedAt = nil
        status = .done
    }

    func markUndone() {
        startedAt = nil
        status = .undone
    }

    func resetElapsed() {
        elapsedSeconds = 0
        startedAt = nil
        status = .done
    }
}
