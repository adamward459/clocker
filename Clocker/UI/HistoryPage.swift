import SwiftUI

struct HistoryEntry: Identifiable {
    let id = UUID()
    let fileName: String
    let fileURL: URL
    let fileSize: String
    let modifiedDate: String
    let lastRecord: String?
    let icon: String
    var isDone: Bool
}

struct HistorySection: Identifiable {
    let id: String
    let projectName: String
    var entries: [HistoryEntry]
}

struct HistoryPage: View {
    @EnvironmentObject var clockModel: ClockModel
    var navigateBack: () -> Void
    var isVisible: Bool = false
    @State private var backHovered = false
    @State private var sections: [HistorySection] = []
    @State private var errorMessage: String?
    private let statusStore = HistoryRecordStatusStore()

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
                        .background(sectionBackground)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
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
                HStack(spacing: 4) {
                    if let lastRecord = entry.lastRecord {
                        Text(lastRecord)
                            .font(ClockerTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(ClockerTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.fileSize)
                        .font(ClockerTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            Button {
                toggleStatus(for: entry)
            } label: {
                statusBadge(isDone: entry.isDone)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isDone ? "Mark as not done" : "Mark as done")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, ClockerTheme.Spacing.rowVertical)
        .background(
            RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                .fill(entry.isDone ? Color.green.opacity(0.07) : Color.red.opacity(0.05))
        )
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
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
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
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
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
        let lastRecord = Self.readLastRecord(from: fileURL)
        return HistoryEntry(
            fileName: fileURL.lastPathComponent,
            fileURL: fileURL,
            fileSize: formatSize(values?.fileSize ?? 0),
            modifiedDate: dateFmt.string(from: values?.contentModificationDate ?? Date()),
            lastRecord: lastRecord,
            icon: iconForFile(fileURL),
            isDone: statusStore.isDone(for: fileURL)
        )
    }

    private static func readLastRecord(from url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.last
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

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
            .fill(ClockerTheme.Colors.hoverFill.opacity(0.25))
    }

    private func statusBadge(isDone: Bool) -> some View {
        let color = isDone ? Color.green : Color.red
        let systemImage = isDone ? "checkmark.circle.fill" : "xmark.circle.fill"

        return Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .padding(4)
            .background(
                Circle()
                    .fill(color.opacity(0.12))
            )
    }

    private func toggleStatus(for entry: HistoryEntry) {
        let nextValue = !entry.isDone
        statusStore.setDone(nextValue, for: entry.fileURL)
        updateStatus(for: entry.fileURL, isDone: nextValue)
    }

    private func updateStatus(for fileURL: URL, isDone: Bool) {
        for sectionIndex in sections.indices {
            guard let entryIndex = sections[sectionIndex].entries.firstIndex(where: { $0.fileURL == fileURL }) else { continue }
            sections[sectionIndex].entries[entryIndex].isDone = isDone
            return
        }
    }
}
