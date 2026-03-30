import SwiftUI

enum PopoverPage {
    case main
    case history
}

struct MenuBarPopover: View {
    @EnvironmentObject var clockModel: ClockModel
    @State private var currentPage: PopoverPage = .main

    var body: some View {
        ZStack(alignment: .top) {
            MainMenuPage(navigateToHistory: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPage = .history
                }
            })
            .offset(x: currentPage == .main ? 0 : -280)
            .opacity(currentPage == .main ? 1 : 0)

            HistoryPage(navigateBack: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPage = .main
                }
            })
            .frame(height: currentPage == .history ? nil : 0)
            .offset(x: currentPage == .history ? 0 : 280)
            .opacity(currentPage == .history ? 1 : 0)
        }
        .frame(width: ClockerTheme.Size.popoverWidth)
        .clipped()
    }
}
