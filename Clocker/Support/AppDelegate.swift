import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let clockModel = ClockModel()
    let loginItemService = LoginItemService()

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

        // Keep button title in sync with the clock
        clockModel.onTimeChange = { [weak self] time in
            self?.updateStatusItemTitle()
        }
        clockModel.onRunningStateChange = { [weak self] _ in
            self?.updateStatusItemTitle()
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover()
                .environmentObject(clockModel)
                .environmentObject(loginItemService)
        )

        clockModel.restoreTodayRecordIfAvailable()
        updateStatusItemTitle()
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
        button.title = " \(clockModel.displayTime)"
    }
}
