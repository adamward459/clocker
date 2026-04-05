import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let modelContainer = ProjectStore.makeModelContainer()
    private lazy var projectRepository: ProjectStore = ProjectStore(
        legacyStorageURL: ClockModel.storageURL,
        modelContainer: modelContainer
    )
    private lazy var clockModel = ClockModel(
        projectRepository: projectRepository,
        timeWriter: TimeWriter(storageURL: ClockModel.storageURL)
    )
    let loginItemService = LoginItemService()
    let appUpdateService = AppUpdateService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
        }

        NSApp.applicationIconImage = NSImage(named: "Logo")

        clockModel.onTimeChange = { [weak self] _ in
            self?.updateStatusItemTitle()
        }
        clockModel.onRunningStateChange = { [weak self] _ in
            self?.updateStatusItemTitle()
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover()
                .environmentObject(clockModel)
                .environmentObject(loginItemService)
                .environmentObject(appUpdateService)
        )

        updateStatusItemTitle()

        if ProcessInfo.processInfo.environment["CLOCKER_SCREENSHOT_MODE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.togglePopover()
            }
        }
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            togglePopover()
        } else {
            toggleClock()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    fileprivate func toggleClock() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if clockModel.isRunning {
            clockModel.stop()
        } else {
            clockModel.start()
        }
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }
        let systemName = clockModel.isRunning ? "pause.fill" : "play.fill"
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        button.image?.isTemplate = true
        button.image?.size = NSSize(width: 12, height: 12)
        button.title = clockModel.menuBarTitle
    }
}
