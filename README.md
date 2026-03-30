# Clocker

Clocker is a native macOS menu bar app for tracking elapsed time throughout the day.

## What it does

- Shows a live `HH:mm:ss` timer in the menu bar
- Lets you start, stop, and reset the current day’s timer
- Persists daily records to a local storage folder
- Restores today’s record when the app launches
- Displays a history view of files in the storage folder
- Supports optional launch at login

## Project Structure

- `Clocker/ClockerApp.swift` - SwiftUI app entry point
- `Clocker/Support/AppDelegate.swift` - menu bar and popover setup
- `Clocker/Models/ClockModel.swift` - timer state, restore logic, and persistence
- `Clocker/Services/TimeWriter.swift` - background file writer
- `Clocker/Services/LoginItemService.swift` - login item integration
- `Clocker/UI/` - menu bar popover screens and theme helpers

## Storage

Clocker uses a build-specific storage folder under `~/Documents`:

- Debug builds use `~/Documents/Clocker-Dev`
- Release builds use `~/Documents/Clocker`

The app writes daily files named like `yyyy-MM-dd.txt` and uses the latest line in each file as the restored timer value for that day.

## Build Notes

- The app can build locally without Apple Developer signing.
- If needed, pass `CODE_SIGNING_ALLOWED=NO` when building from the command line.

## Development

This is an Xcode project:

1. Open `Clocker.xcodeproj` in Xcode.
2. Build and run the macOS app target.
3. Use the menu bar icon to open the popover and test timer behavior.

## License

No license file is currently included in the repository.
