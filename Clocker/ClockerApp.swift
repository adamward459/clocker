import SwiftUI

@main
struct ClockerApp: App {
    @StateObject private var store = ClockStore()
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Label {
                Text(store.formattedElapsed)
                    .monospacedDigit()
            } icon: {
                Image(systemName: store.isRunning ? "timer.circle.fill" : "timer.circle")
            }
        }
        .menuBarExtraStyle(.window)

        Window("History", id: "history") {
            HistoryView(store: store)
        }
        .defaultSize(width: 460, height: 520)

        Settings {
            SettingsView(store: store, launchAtLoginManager: launchAtLoginManager)
        }
    }
}
