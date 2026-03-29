import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClockStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Settings", systemImage: "gearshape.2.fill")
                    .font(.title2.weight(.semibold))

                Text("Tune startup behavior and choose where daily records are saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )) {
                        settingsRowLabel(
                            title: "Launch at login",
                            detail: "Open Clocker automatically when you sign in.",
                            systemImage: "power.circle"
                        )
                    }

                    Button {
                        openWindow(id: "history")
                    } label: {
                        settingsRowLabel(
                            title: "Open History",
                            detail: "Review saved records in a dedicated window.",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label("General", systemImage: "switch.2")
                }

                Section {
                    HStack {
                        settingsRowLabel(
                            title: "Current folder",
                            detail: store.selectedFolderURL?.path(percentEncoded: false) ?? "No external folder selected yet.",
                            systemImage: "folder"
                        )
                        Spacer()
                        Text(store.selectedFolderURL?.lastPathComponent ?? "Local Only")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button {
                        store.chooseSaveFolder()
                    } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                    }

                    if store.selectedFolderURL != nil {
                        Button(role: .destructive) {
                            store.clearSaveFolder()
                        } label: {
                            Label("Use Local Only", systemImage: "externaldrive.badge.minus")
                        }
                    }
                } header: {
                    Label("Save Folder", systemImage: "externaldrive")
                }

                Section {
                    HStack {
                        settingsRowLabel(
                            title: "Save status",
                            detail: "Clocker keeps the current day cached locally and can mirror it to your chosen folder.",
                            systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                        )
                        Spacer()
                        SyncStatusView(state: store.syncState, emphasis: .prominent)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Label("Storage", systemImage: "internaldrive")
                }
            }
            .formStyle(.grouped)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func settingsRowLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
