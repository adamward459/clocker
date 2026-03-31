import SwiftUI

struct HistoryEntry: Identifiable {
    let id = UUID()
    let fileName: String
    let fileSize: String
    let modifiedDate: String
    let icon: String
}

struct HistorySection: Identifiable {
    let id: String
    let projectName: String
    let entries: [HistoryEntry]
}

struct HistoryPage: View {
    @EnvironmentObject var clockModel: ClockModel
    var navigateBack: () -> Void
    var isVisible: Bool = false
    @State private var backHovered = false
    @State private var sections: [HistorySection] = []
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
            } else if sections.isEmpty {
                emptyState(icon: "folder.badge.questionmark", message: "No records found")
            } else {
                fileList
            }
        }
        .onAppear { loadEntries() }
        .onChange(of: isVisible) { _, visible in
            if visible { loadEntries() }
        }
        .onChange(of: clockModel.projects) { _, _ in
            if isVisible { loadEntries() }
        }
    }

    private var fileList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(section.projectName)
                                .font(ClockerTheme.Fonts.navTitle)
                            Spacer()
                            Text("\(section.entries.count)")
                                .font(ClockerTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 18)

                        VStack(spacing: 0) {
                            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                historyEntryRow(entry)

                                if index < section.entries.count - 1 {
                                    Divider()
                                        .padding(.leading, 48)
                                        .padding(.trailing, 18)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                                .fill(ClockerTheme.Colors.hoverFill.opacity(0.25))
                        )
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
            .allowsHitTesting(false)
        }
        .frame(maxHeight: ClockerTheme.Size.historyMaxHeight)
    }

    private func historyEntryRow(_ entry: HistoryEntry) -> some View {
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
            sections = []
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

            var nextSections: [HistorySection] = []
            let ignoredRootFileNames: Set<String> = ["projects.json", "state.json"]

            let sortedContents = contents.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }

            let rootFiles = sortedContents.filter { url in
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return !isDirectory.boolValue && !ignoredRootFileNames.contains(url.lastPathComponent)
            }

            let rootEntries = rootFiles.map { fileURL in
                makeEntry(fileURL, dateFmt: dateFmt)
            }
            if !rootEntries.isEmpty {
                nextSections.append(historySection(id: ClockProject.defaultID, entries: rootEntries))
            }

            let projectDirectories = sortedContents.filter { url in
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return isDirectory.boolValue
            }

            for directory in projectDirectories {
                let directoryEntries = (try? fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []

                let entries = directoryEntries
                    .sorted {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                    }
                    .filter { fileURL in
                        var isDirectory: ObjCBool = false
                        fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
                        return !isDirectory.boolValue
                    }
                    .map { fileURL in
                        makeEntry(fileURL, dateFmt: dateFmt)
                    }

                guard !entries.isEmpty else { continue }

                nextSections.append(historySection(id: directory.lastPathComponent, entries: entries))
            }

            let sectionByID = Dictionary(uniqueKeysWithValues: nextSections.map { ($0.id, $0) })
            var orderedSections: [HistorySection] = []

            for project in clockModel.orderedProjects {
                if let section = sectionByID[project.id] {
                    orderedSections.append(section)
                }
            }

            for section in nextSections where !clockModel.projects.contains(where: { $0.id == section.id }) {
                orderedSections.append(section)
            }

            sections = orderedSections
            errorMessage = nil
        } catch {
            errorMessage = "Unable to read folder"
            sections = []
        }
    }

    private func historySection(id: String, entries: [HistoryEntry]) -> HistorySection {
        HistorySection(
            id: id,
            projectName: clockModel.projectName(for: id),
            entries: entries
        )
    }

    private func makeEntry(_ fileURL: URL, dateFmt: DateFormatter) -> HistoryEntry {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return HistoryEntry(
            fileName: fileURL.lastPathComponent,
            fileSize: formatSize(values?.fileSize ?? 0),
            modifiedDate: dateFmt.string(from: values?.contentModificationDate ?? Date()),
            icon: iconForFile(fileURL)
        )
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
