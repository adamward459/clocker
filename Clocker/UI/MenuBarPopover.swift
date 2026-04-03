import SwiftUI

enum PopoverPage {
    case main
    case history
    case projects
}

private enum PageNavigationDirection {
    case forward
    case backward

    var transition: AnyTransition {
        switch self {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
}

struct MenuBarPopover: View {
    @EnvironmentObject var clockModel: ClockModel
    @State private var currentPage: PopoverPage = .main
    @State private var navigationDirection: PageNavigationDirection = .forward

    var body: some View {
        Group {
            switch currentPage {
            case .main:
                MainMenuPage(
                    navigateToHistory: { navigate(to: .history, direction: .forward) },
                    navigateToProjects: { navigate(to: .projects, direction: .forward) }
                )
            case .history:
                HistoryPage(
                    navigateBack: { navigate(to: .main, direction: .backward) },
                    isVisible: true
                )
            case .projects:
                ProjectsPage(
                    navigateBack: { navigate(to: .main, direction: .backward) },
                    isVisible: true
                )
            }
        }
        .id(currentPage)
        .transition(navigationDirection.transition)
        .frame(width: ClockerTheme.Size.popoverWidth)
    }

    private func navigate(to page: PopoverPage, direction: PageNavigationDirection) {
        withAnimation(.easeInOut(duration: 0.22)) {
            navigationDirection = direction
            currentPage = page
        }
    }
}
