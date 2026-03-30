import SwiftUI
import Combine

final class ClockModel: ObservableObject {
    @Published var displayTime: String = "00:00"
    @Published var isRunning: Bool = false
    var onTimeChange: ((String) -> Void)?

    static let storagePath = "~/Documents/Clocker"

    var resolvedStorageURL: URL {
        let expanded = NSString(string: Self.storagePath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private var timer: AnyCancellable?
    private let timeWriter: TimeWriter
    private var elapsedSeconds: Int = 0

    init() {
        let expanded = NSString(string: Self.storagePath).expandingTildeInPath
        timeWriter = TimeWriter(storageURL: URL(fileURLWithPath: expanded))
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                let formatted = self.formatElapsed(self.elapsedSeconds)
                self.displayTime = formatted
                self.onTimeChange?(formatted)
                self.timeWriter.persist(formatted)
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    func reset() {
        stop()
        elapsedSeconds = 0
        displayTime = "00:00"
        onTimeChange?(displayTime)
    }

    private func formatElapsed(_ totalSeconds: Int) -> String {
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
