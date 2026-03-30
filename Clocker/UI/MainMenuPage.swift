import SwiftUI

struct MainMenuPage: View {
    @EnvironmentObject var clockModel: ClockModel
    @State private var openAtLogin = false
    @State private var storagePath: String = "~/Documents/Clocker"
    var navigateToHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Clock header
            VStack(spacing: 6) {
                Text(clockModel.currentTime)
                    .font(ClockerTheme.Fonts.clockDisplay)
                    .monospacedDigit()
                Text(formattedDate)
                    .font(ClockerTheme.Fonts.dateLabel)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)

            // Menu rows
            VStack(spacing: 2) {
                // Open at Login
                HoverRow {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "power")
                        Text("Open at Login")
                            .font(ClockerTheme.Fonts.rowLabel)
                        Spacer()
                        Toggle("", isOn: $openAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                }

                // Storage folder
                Button {
                    chooseFolder()
                } label: {
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        MenuIcon(systemName: "folder")
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Storage")
                                .font(ClockerTheme.Fonts.rowLabel)
                            Text(displayPath)
                                .font(ClockerTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
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

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private var displayPath: String {
        storagePath.replacingOccurrences(
            of: NSHomeDirectory(),
            with: "~"
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Storage Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            storagePath = url.path(percentEncoded: false)
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
