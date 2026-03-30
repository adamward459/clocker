# AGENTS.md

This repository contains **Clocker**, a native macOS menu bar app written in SwiftUI.

## Quick Context

- App entry point: `Clocker/ClockerApp.swift`
- App delegate / menu bar setup: `Clocker/Support/AppDelegate.swift`
- Core timer state and persistence: `Clocker/Models/ClockModel.swift`
- File writer: `Clocker/Services/TimeWriter.swift`
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
- It tracks elapsed time and persists daily records under `~/Documents/Clocker`.
- It supports restoring today’s record, opening the storage folder, and toggling launch at login.
- History view reads files from the storage folder and shows metadata for each entry.

## Verification

- For code changes, run the smallest relevant build or test command available in the repo.
- If changes affect the UI or persistence, verify the affected Swift files compile together.
- Keep documentation in sync with app behavior when behavior changes.
