import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var lastUsedAt: Date?
    @Relationship(deleteRule: .cascade) var sessions: [Session]

    static let defaultName = "Inbox"

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        sessions: [Session] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.sessions = sessions
    }
}
