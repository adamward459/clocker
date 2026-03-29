import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ClockStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Clocker", systemImage: "timer")
                            .font(.headline.weight(.semibold))

                        Text(store.isRunning ? "Tracking time live" : "Paused for today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    statusBadge
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.formattedElapsed)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    HStack(spacing: 10) {
                        Label(DateKey.displayString(from: store.activeDateKey), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let folderName = store.selectedFolderURL?.lastPathComponent {
                            Label(folderName, systemImage: "folder")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.16),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            HStack(spacing: 12) {
                Button {
                    if store.isRunning {
                        store.stop()
                    } else {
                        store.start()
                    }
                } label: {
                    Label(
                        store.isRunning ? "Stop Timer" : "Start Timer",
                        systemImage: store.isRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset Today", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(spacing: 6) {
                quickActionButton(
                    title: "Open History",
                    systemImage: "clock.arrow.circlepath",
                    detail: "Review today's total and previous days"
                ) {
                    openWindow(id: "history")
                }

                quickActionButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    detail: "Choose a save folder and launch options"
                ) {
                    openSettings()
                }

                quickActionButton(
                    title: "Quit Clocker",
                    systemImage: "power",
                    detail: "Close the menu bar app"
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 356)
        .confirmationDialog(
            "Reset today’s timer?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                store.resetToday()
            }
        } message: {
            Text("This clears today’s elapsed time and keeps the date active.")
        }
        .onAppear {
            store.reconcileCurrentDay()
        }
    }

    private var statusBadge: some View {
        Label(
            store.isRunning ? "Running" : "Paused",
            systemImage: store.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle.fill"
        )
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(store.isRunning ? Color.green.opacity(0.16) : Color.secondary.opacity(0.14))
        .foregroundStyle(store.isRunning ? .green : .secondary)
        .clipShape(Capsule())
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
