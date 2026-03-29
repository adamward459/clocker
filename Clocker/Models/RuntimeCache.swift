import Foundation

struct RuntimeCache: Codable, Equatable, Sendable {
    var dateKey: String
    var elapsedSeconds: Int
    var isRunning: Bool
    var updatedAt: Date
}
