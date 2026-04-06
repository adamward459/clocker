import Foundation

struct ClockState {
    var displayTime: String = "00:00"
    var isRunning: Bool = false
    var restoreState: ClockService.RestoreState = .idle
    var projects: [Project] = []
    var activeProjectID: UUID = UUID()
    var dataRevision: UUID = UUID()
    var activeSession: Session?
    var trackingDate: String = ClockService.todayString()
}
