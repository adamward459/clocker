import Combine
import Foundation

@MainActor
final class ClockTimerDriver {
    private let onTick: () -> Void
    private var timer: AnyCancellable?

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func beginRunningTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onTick()
            }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }
}
