import Foundation

struct ClockProject: Identifiable, Codable, Equatable {
    static let defaultID = "default"
    static let defaultProjectName = "Inbox"

    let id: String
    var name: String
    var lastUsedAt: Date?

    init(id: String = UUID().uuidString, name: String, lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.lastUsedAt = lastUsedAt
    }

    var isDefault: Bool {
        id == Self.defaultID
    }

    static var defaultProject: ClockProject {
        ClockProject(id: Self.defaultID, name: Self.defaultProjectName)
    }
}
