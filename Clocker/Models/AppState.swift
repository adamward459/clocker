import Foundation
import SwiftData

@Model
final class AppState {
    @Relationship(deleteRule: .nullify) var selectedProject: Project?
    @Relationship(deleteRule: .nullify) var currentSession: Session?

    init(
        selectedProject: Project? = nil,
        currentSession: Session? = nil
    ) {
        self.selectedProject = selectedProject
        self.currentSession = currentSession
    }
}
