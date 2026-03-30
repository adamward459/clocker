import SwiftUI

struct HistoryEntry: Identifiable {
    let id = UUID()
    let fileName: String
    let fileSize: String
    let modifiedDate: String
    let icon: String
}

struct HistoryPage: View {
    @EnvironmentObject var clockModel: ClockModel
    var navigateBack: () -> Void
    var isVisible: Bool = false
    @State private var backHovered = false
    @State private var entries: [HistoryEntry] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(ClockerTheme.Fonts.navBackIcon)
                        Text("Back")
                            .font(ClockerTheme.Fonts.navBack)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                            .fill(backHovered ? ClockerTheme.Colors.hoverFill : .clear)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .onHover { backHovered = $0 }
                .animation(.easeInOut(duration: 0.15), value: backHovered)

                Spacer()

                Text("History")
                    .font(ClockerTheme.Fonts.navTitle)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(ClockerTheme.Fonts.navBackIcon)
                    Text("Back")
                        .font(ClockerTheme.Fonts.navBack)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .hidden()
            }
            .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)

            if let error = errorMessage {
                emptyState(icon: "exclamationmark.triangle", message: error)
            } else if entries.isEmpty {
                emptyState(icon: "folder.badge.questionmark", message: "No records found")
            } else {
                fileList
            }
        }
        .onChange(of: isVisible) { _, visible in
            if visible { loadEntries() }
        }
    }

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                        Image(systemName: entry.icon)
                            .font(ClockerTheme.Fonts.historyIcon)
                            .foregroundStyle(ClockerTheme.Colors.rowIcon)
                            .frame(width: ClockerTheme.Size.iconWidth, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.fileName)
                                .font(ClockerTheme.Fonts.rowLabel)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(entry.fileSize) · \(entry.modifiedDate)")
                                .font(ClockerTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, ClockerTheme.Spacing.rowVertical)

                    if index < entries.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                            .padding(.trailing, 18)
                    }
                }
            }
            .padding(.vertical, 6)
            .allowsHitTesting(false)
        }
        .frame(maxHeight: ClockerTheme.Size.historyMaxHeight)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(message)
                .font(ClockerTheme.Fonts.rowLabel)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func loadEntries() {
        let url = clockModel.resolvedStorageURL
        let fm = FileManager.default

        guard fm.fileExists(atPath: url.path) else {
            errorMessage = "Folder does not exist"
            entries = []
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let dateFmt = DateFormatter()
            dateFmt.dateStyle = .medium
            dateFmt.timeStyle = .short

            entries = contents
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { fileURL in
                    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    return HistoryEntry(
                        fileName: fileURL.lastPathComponent,
                        fileSize: formatSize(values?.fileSize ?? 0),
                        modifiedDate: dateFmt.string(from: values?.contentModificationDate ?? Date()),
                        icon: iconForFile(fileURL)
                    )
                }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to read folder"
            entries = []
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func iconForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "json": return "doc.text.fill"
        case "csv": return "tablecells.fill"
        case "txt", "log": return "doc.plaintext.fill"
        case "sqlite", "db": return "cylinder.fill"
        default:
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue ? "folder.fill" : "doc.fill"
        }
    }
}
