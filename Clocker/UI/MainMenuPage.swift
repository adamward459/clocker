import SwiftUI

struct MainMenuPage: View {
    @EnvironmentObject var clockModel: ClockModel
    @EnvironmentObject var loginItemService: LoginItemService
    @EnvironmentObject var appUpdateService: AppUpdateService
    var navigateToHistory: () -> Void
    var navigateToProjects: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Stopwatch header
            VStack(spacing: 10) {
                Button(action: navigateToProjects) {
                    HStack(spacing: 4) {
                        Text(clockModel.activeProjectName)
                            .font(ClockerTheme.Fonts.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ClockerTheme.Colors.hoverFill)
                    )
                }
                .buttonStyle(.plain)

                Text(clockModel.displayTime)
                    .font(ClockerTheme.Fonts.clockDisplay)
                    .monospacedDigit()

                statusLine

                HStack(spacing: 12) {
                    if clockModel.isRunning {
                        Button("Stop") { clockModel.stop() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button("Start") { clockModel.start() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    if !clockModel.isRunning && clockModel.displayTime != "00:00" {
                        Button("Reset") { clockModel.reset() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)

            VStack(spacing: 2) {
                // Open at Login
                HoverRow {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "power")
                        Text("Open at Login")
                            .font(ClockerTheme.Fonts.rowLabel)
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { loginItemService.isEnabled },
                                set: { loginItemService.setEnabled($0) }
                            )
                        )
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                }

                // Storage
                Button {
                    let url = clockModel.resolvedStorageURL
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: url.path) {
                        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
                    }
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "folder")
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Storage")
                                .font(ClockerTheme.Fonts.rowLabel)
                            Text(clockModel.resolvedStorageURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(ClockerTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(ClockerTheme.Fonts.chevron)
                            .foregroundStyle(ClockerTheme.Colors.trailingAccessory)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuRowButtonStyle())

                // History
                Button(action: navigateToHistory) {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "clock.arrow.circlepath")
                        Text("History")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(ClockerTheme.Fonts.chevron)
                            .foregroundStyle(ClockerTheme.Colors.trailingAccessory)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuRowButtonStyle())

                if appUpdateService.isAvailable {
                    Button {
                        appUpdateService.checkForUpdates()
                    } label: {
                        HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                            MenuIcon(systemName: appUpdateService.status.symbolName)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(appUpdateService.status.title)
                                    .font(ClockerTheme.Fonts.rowLabel)
                                Text(appUpdateService.status.subtitle)
                                    .font(ClockerTheme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                            }
                            Spacer()
                            if let progress = appUpdateService.status.progress {
                                ProgressView(value: progress)
                                    .frame(width: 44)
                            } else if appUpdateService.status.isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(ClockerTheme.Fonts.chevron)
                                    .foregroundStyle(ClockerTheme.Colors.trailingAccessory)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(ClockerTheme.Colors.hoverFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(MenuRowButtonStyle())
                    .disabled(appUpdateService.status.isBusy)
                }

                Divider()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 2)

                // Quit
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "xmark.circle")
                        Text("Quit Clocker")
                        Spacer()
                        Text("⌘Q")
                            .font(ClockerTheme.Fonts.shortcut)
                            .foregroundStyle(ClockerTheme.Colors.trailingAccessory)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuRowButtonStyle())
                .keyboardShortcut("q")

                HStack {
                    Spacer()
                    Text(appVersionLabel)
                        .font(ClockerTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
                .padding(.top, 2)
            }
            .padding(.vertical, ClockerTheme.Spacing.sectionGap)
        }
        .alert(item: $appUpdateService.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch clockModel.restoreState {
        case .restoring:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Restoring today's record")
                    .font(ClockerTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        case .restored:
            statusText(label: "Restored today's record", systemImage: "checkmark.circle")
        case .unavailable, .idle:
            statusText(label: clockModel.isRunning ? "Tracking time" : "Ready to start", systemImage: clockModel.isRunning ? "timer" : "pause.circle")
        }
    }

    private func statusText(label: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(ClockerTheme.Fonts.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        guard let build, !build.isEmpty else { return "Version \(version)" }
        return "Version \(version) (\(build))"
    }
}

// MARK: - Reusable row components

struct MenuIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(ClockerTheme.Fonts.rowIcon)
            .frame(width: ClockerTheme.Size.iconWidth, alignment: .center)
            .foregroundStyle(ClockerTheme.Colors.rowIcon)
    }
}

struct HoverRow<Content: View>: View {
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, ClockerTheme.Spacing.rowHorizontal)
            .padding(.vertical, ClockerTheme.Spacing.rowVertical)
            .background(
                RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                    .fill(isHovered ? ClockerTheme.Colors.hoverFill : .clear)
            )
            .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
