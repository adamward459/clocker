import Foundation

struct DailyRecord: Codable, Equatable, Identifiable, Sendable {
    let dateKey: String
    var elapsedSeconds: Int
    var updatedAt: Date

    var id: String { dateKey }
}
