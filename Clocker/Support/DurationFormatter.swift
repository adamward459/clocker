import Foundation

enum DurationFormatter {
    static func string(from totalSeconds: Int) -> String {
        let safeSeconds = max(0, totalSeconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let seconds = safeSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
