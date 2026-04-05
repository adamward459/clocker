import Foundation
import SwiftData

@Model
final class Session {
    enum Status: String, Codable, CaseIterable {
        case done
        case undone
    }

    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var startAt: Date
    var endAt: Date?
    var createdAt: Date
    var status: Status

    init(
        id: UUID = UUID(),
        projectId: UUID,
        startAt: Date,
        endAt: Date? = nil,
        createdAt: Date = .now,
        status: Status
    ) {
        self.id = id
        self.projectId = projectId
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
        self.status = status
    }
}
