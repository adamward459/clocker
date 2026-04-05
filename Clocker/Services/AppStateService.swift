import Foundation
import SwiftData

@MainActor
final class AppStateService {
    private let repository: AppStateRepository

    init(repository: AppStateRepository) {
        self.repository = repository
    }

    convenience init(modelContainer: ModelContainer) {
        self.init(repository: SwiftDataAppStateRepository(modelContainer: modelContainer))
    }

    func loadAppState() -> AppState? {
        repository.loadAppState()
    }

    func loadOrCreateAppState() -> AppState {
        repository.loadOrCreateAppState()
    }

    func setSelectedProject(_ project: Project?) {
        repository.updateSelectedProject(project)
    }

    func setCurrentSession(_ session: Session?) {
        repository.updateCurrentSession(session)
    }

    func clearCurrentSession() {
        repository.clearCurrentSession()
    }
}
