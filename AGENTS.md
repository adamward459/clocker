# AGENTS.md

This repository contains **Clocker**, a native macOS menu bar app written in SwiftUI.

## Quick Context

- App entry point: `Clocker/ClockerApp.swift`
- App delegate / menu bar setup: `Clocker/Support/AppDelegate.swift`
- Core timer store: `Clocker/Services/ClockService.swift`
- Timer driver: `Clocker/Services/ClockTimerDriver.swift`
- Initial state restore: `Clocker/Services/ClockStateRestorer.swift`
- SwiftData repositories and services: `Clocker/Repository/*`, `Clocker/Services/*`
- Login item integration: `Clocker/Services/LoginItemService.swift`
- Menu bar UI: `Clocker/UI/*`

## Working Rules

- Start with fast search (`rg`, `rg --files`) before reading files.
- Read only the smallest relevant code regions first.
- Prefer incremental changes over broad rewrites.
- Do not revert user changes unless explicitly asked.
- Use `apply_patch` for manual edits.

## App Behavior Notes

- The app runs as a menu bar app with a popover UI.
- It tracks elapsed time with SwiftData-backed projects and sessions.
- It restores the current project/session state from SwiftData on launch and keeps persistence off the file system for the main app flow.
- It supports restoring today’s record and toggling launch at login.
- History view reads SwiftData sessions and groups them by project and date.

## Architecture Notes

- Prefer SOLID boundaries: keep views thin, move persistence into repositories/services, and keep domain rules in store methods rather than in UI code.
- Treat `ClockService` as the store that owns published state, `ClockStateRestorer` as the pure snapshot builder, and `ClockTimerDriver` as the time/event driver.
- Treat `AppState` as the persisted pointer record for the selected project and current session.
- Avoid adding new file-based persistence for core timer/history features unless the task explicitly calls for legacy compatibility.

## Verification

- For code changes, run the smallest relevant build or test command available in the repo.
- If changes affect the UI or persistence, verify the affected Swift files compile together.
- Keep documentation in sync with app behavior when behavior changes.
