# Clocker

Clocker is a native macOS menu bar app for tracking today's elapsed time.

## Features

- Live `HH:mm:ss` timer in the menu bar
- Start, stop, and reset controls
- Daily rollover at local midnight
- History view with today's total and past immutable dates
- Local current-day cache for resilience
- Optional user-chosen folder for importing and saving day files
- Optional launch at login

## Notes

- The app builds without Apple Developer signing requirements.
- If you choose a folder in Settings, Clocker imports existing `yyyy-MM-dd.json` files from that folder and keeps saving future day records there.
- The app can still build locally without signing by passing `CODE_SIGNING_ALLOWED=NO`.
