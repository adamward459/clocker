import Foundation
import ServiceManagement

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = Self.currentStatus().isEnabled
    }

    func refresh() {
        isEnabled = Self.currentStatus().isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
        } catch {
            refresh()
            print("Failed to update open at login: \(error)")
        }
    }

    private static func currentStatus() -> SMAppService.Status {
        SMAppService.mainApp.status
    }
}

private extension SMAppService.Status {
    var isEnabled: Bool {
        switch self {
        case .enabled:
            return true
        case .requiresApproval, .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }
}
