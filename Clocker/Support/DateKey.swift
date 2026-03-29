import Foundation

enum DateKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date, calendar: Calendar) -> String {
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    static func displayString(from key: String) -> String {
        let input = DateFormatter()
        input.calendar = .autoupdatingCurrent
        input.locale = Locale(identifier: "en_US_POSIX")
        input.timeZone = .autoupdatingCurrent
        input.dateFormat = "yyyy-MM-dd"

        let output = DateFormatter()
        output.calendar = .autoupdatingCurrent
        output.locale = .autoupdatingCurrent
        output.timeZone = .autoupdatingCurrent
        output.dateStyle = .medium

        guard let date = input.date(from: key) else {
            return key
        }

        return output.string(from: date)
    }
}
