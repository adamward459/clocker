import Foundation
import SwiftData

@MainActor
protocol AppStateRepository: AnyObject {
    func loadAppState() -> AppState?
    func loadOrCreateAppState() -> AppState
    func saveAppState(_ appState: AppState)
    func updateSelectedProject(_ project: Project?)
    func updateCurrentSession(_ session: Session?)
    func clearCurrentSession()
}

@MainActor
final class SwiftDataAppStateRepository: AppStateRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    func loadAppState() -> AppState? {
        let descriptor = FetchDescriptor<AppState>()
        return try? modelContext.fetch(descriptor).first
    }

    func loadOrCreateAppState() -> AppState {
        if let appState = loadAppState() {
            return appState
        }

        let appState = AppState()
        modelContext.insert(appState)
        try? modelContext.save()
        return appState
    }

    func saveAppState(_ appState: AppState) {
        if loadAppState() == nil {
            modelContext.insert(appState)
        }

        try? modelContext.save()
    }

    func updateSelectedProject(_ project: Project?) {
        let appState = loadOrCreateAppState()
        appState.selectedProject = project
        try? modelContext.save()
    }

    func updateCurrentSession(_ session: Session?) {
        let appState = loadOrCreateAppState()
        appState.currentSession = session
        try? modelContext.save()
    }

    func clearCurrentSession() {
        updateCurrentSession(nil)
    }
}
