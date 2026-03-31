import SwiftUI

enum PopoverPage {
    case main
    case history
    case projects
}

struct MenuBarPopover: View {
    @EnvironmentObject var clockModel: ClockModel
    @State private var currentPage: PopoverPage = .main

    var body: some View {
        Group {
            switch currentPage {
            case .main:
                MainMenuPage(
                    navigateToHistory: { currentPage = .history },
                    navigateToProjects: { currentPage = .projects }
                )
            case .history:
                HistoryPage(
                    navigateBack: { currentPage = .main },
                    isVisible: true
                )
            case .projects:
                ProjectsPage(
                    navigateBack: { currentPage = .main },
                    isVisible: true
                )
            }
        }
        .frame(width: ClockerTheme.Size.popoverWidth)
    }
}
