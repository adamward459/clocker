import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var sessions: [Session]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        sessions: [Session] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sessions = sessions
    }
}
