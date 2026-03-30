import SwiftUI

struct MainMenuPage: View {
    @EnvironmentObject var clockModel: ClockModel
    @EnvironmentObject var loginItemService: LoginItemService
    var navigateToHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Stopwatch header
            VStack(spacing: 10) {
                Text(clockModel.displayTime)
                    .font(ClockerTheme.Fonts.clockDisplay)
                    .monospacedDigit()

                if clockModel.restoreState == .restoring {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Restoring today's record")
                            .font(ClockerTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

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
            .padding(.bottom, 20)
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

                // Storage info (read-only, opens in Finder on click)
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
            }
            .padding(.vertical, ClockerTheme.Spacing.sectionGap)
        }
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
