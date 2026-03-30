import SwiftUI
import Combine

final class ClockModel: ObservableObject {
    @Published var currentTime: String = ""
    var onTimeChange: ((String) -> Void)?

    private var timer: AnyCancellable?
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        currentTime = formatter.string(from: Date())
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .map { [formatter] in formatter.string(from: $0) }
            .sink { [weak self] time in
                self?.currentTime = time
                self?.onTimeChange?(time)
            }
    }
}
