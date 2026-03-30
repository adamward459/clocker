import SwiftUI
import Combine

final class ClockModel: ObservableObject, @unchecked Sendable {
    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored
        case unavailable
    }

    @Published var displayTime: String = "00:00"
    @Published var isRunning: Bool = false
    @Published var restoreState: RestoreState = .idle
    var onTimeChange: ((String) -> Void)?
    var onRunningStateChange: ((Bool) -> Void)?

    static var storageFolderName: String {
        storageFolderName(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static func storageFolderName(bundleIdentifier: String?) -> String {
        if bundleIdentifier?.contains(".dev") == true {
            return "Clocker-Dev"
        }

        #if DEBUG
        return "Clocker-Dev"
        #else
        return "Clocker"
        #endif
    }

    static var storageURL: URL {
        let documents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documents.appendingPathComponent(storageFolderName, isDirectory: true)
    }

    var resolvedStorageURL: URL { Self.storageURL }

    private var timer: AnyCancellable?
    private let timeWriter: TimeWriter
    private var elapsedSeconds: Int = 0
    private var restoreFeedbackWorkItem: DispatchWorkItem?

    convenience init() {
        self.init(timeWriter: TimeWriter(storageURL: Self.storageURL))
    }

    init(timeWriter: TimeWriter) {
        self.timeWriter = timeWriter
    }

    func restoreTodayRecordIfAvailable() {
        guard !isRunning else { return }

        let url = Self.currentDayFileURL(storageURL: resolvedStorageURL)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            restoreState = .unavailable
            return
        }

        restoreFeedbackWorkItem?.cancel()
        let feedbackWorkItem = DispatchWorkItem { [weak self] in
            self?.restoreState = .restoring
        }
        restoreFeedbackWorkItem = feedbackWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: feedbackWorkItem)

        DispatchQueue.global(qos: .utility).async { [url, weak self] in
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let restoredSeconds = Self.parseElapsedSeconds(from: contents)

            DispatchQueue.main.async {
                guard let self else { return }
                self.restoreFeedbackWorkItem?.cancel()
                self.restoreFeedbackWorkItem = nil

                guard let restoredSeconds else {
                    self.restoreState = .unavailable
                    return
                }

                self.elapsedSeconds = restoredSeconds
                self.displayTime = Self.formatElapsed(restoredSeconds)
                self.onTimeChange?(self.displayTime)
                self.restoreState = .restored
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        onRunningStateChange?(true)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                let formatted = Self.formatElapsed(self.elapsedSeconds)
                self.displayTime = formatted
                self.onTimeChange?(formatted)
                self.timeWriter.persist(formatted)
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        onRunningStateChange?(false)
    }

    func reset() {
        stop()
        timeWriter.clearTodayRecord()
        elapsedSeconds = 0
        displayTime = "00:00"
        onTimeChange?(displayTime)
        onRunningStateChange?(false)
    }

    static func currentDayFileURL(storageURL: URL, date: Date = Date()) -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let fileName = fmt.string(from: date) + ".txt"
        return storageURL.appendingPathComponent(fileName)
    }

    static func parseElapsedSeconds(from contents: String) -> Int? {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return nil }
        return parseTimeString(lastLine)
    }

    static func parseTimeString(_ value: String) -> Int? {
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        if numbers.count == 2 {
            return numbers[0] * 60 + numbers[1]
        } else {
            return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        }
    }

    static func formatElapsed(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
