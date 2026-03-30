import SwiftUI
import Combine

final class ClockModel: ObservableObject {
    @Published var currentTime: String = ""
    var onTimeChange: ((String) -> Void)?

    static let storagePath = "~/Documents/Clocker"

    var resolvedStorageURL: URL {
        let expanded = NSString(string: Self.storagePath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private var timer: AnyCancellable?
    private let timeWriter: TimeWriter
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        let expanded = NSString(string: Self.storagePath).expandingTildeInPath
        timeWriter = TimeWriter(storageURL: URL(fileURLWithPath: expanded))

        currentTime = formatter.string(from: Date())
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .map { [formatter] in formatter.string(from: $0) }
            .sink { [weak self] time in
                self?.currentTime = time
                self?.onTimeChange?(time)
                self?.timeWriter.persist(time)
            }
    }
}
