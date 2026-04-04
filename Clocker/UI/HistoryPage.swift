import SwiftUI

enum HistoryViewMode: String, CaseIterable, Identifiable {
    case files
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files:
            return "Files"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }
}

struct HistoryEntry: Identifiable {
    let id: String
    let title: String
    let fileURL: URL?
    let secondaryText: String?
    let accessoryText: String?
    let trailingText: String?
    let icon: String
    var isDone: Bool
    let allowsStatusToggle: Bool
    var children: [HistoryEntry]

    init(
        id: String = UUID().uuidString,
        title: String,
        fileURL: URL?,
        secondaryText: String?,
        accessoryText: String?,
        trailingText: String?,
        icon: String,
        isDone: Bool,
        allowsStatusToggle: Bool,
        children: [HistoryEntry] = []
    ) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.secondaryText = secondaryText
        self.accessoryText = accessoryText
        self.trailingText = trailingText
        self.icon = icon
        self.isDone = isDone
        self.allowsStatusToggle = allowsStatusToggle
        self.children = children
    }
}

struct HistorySection: Identifiable {
    let id: String
    let projectName: String
    var summaryText: String?
    var entries: [HistoryEntry]
}

struct HistoryPage: View {
    static let viewModeStorageKey = "history.viewMode"

    @EnvironmentObject var clockModel: ClockModel
    @AppStorage(Self.viewModeStorageKey) private var viewModeRawValue = HistoryViewMode.files.rawValue

    var navigateBack: () -> Void
    var isVisible: Bool = false
    @State private var backHovered = false
    @State private var sections: [HistorySection] = []
    @State private var expandedEntryIDs: Set<String> = []
    @State private var errorMessage: String?
    private let statusStore = HistoryRecordStatusStore()

    private var viewMode: HistoryViewMode {
        get { HistoryViewMode(rawValue: viewModeRawValue) ?? .files }
        set { viewModeRawValue = newValue.rawValue }
    }

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

            Picker("History view", selection: $viewModeRawValue) {
                ForEach(HistoryViewMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, ClockerTheme.Spacing.sectionPadding)
            .padding(.vertical, 10)

            if let error = errorMessage {
                emptyState(icon: "exclamationmark.triangle", message: error)
            } else if sections.isEmpty {
                emptyState(icon: "folder.badge.questionmark", message: "No records found")
            } else {
                historyList
            }
        }
        .onAppear { loadEntries() }
        .onChange(of: isVisible) { _, visible in
            if visible { loadEntries() }
        }
        .onChange(of: viewModeRawValue) { _, _ in
            if isVisible { loadEntries() }
        }
        .onChange(of: clockModel.projects) { _, _ in
            if isVisible { loadEntries() }
        }
    }

    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(section.projectName)
                                .font(ClockerTheme.Fonts.navTitle)
                            Spacer()
                            Text(section.summaryText ?? "\(section.entries.count)")
                                .font(ClockerTheme.Fonts.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 18)

                        VStack(spacing: 0) {
                            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                historyEntryNode(entry)

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

    private func historyEntryNode(_ entry: HistoryEntry, depth: Int = 0) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                historyEntryRow(entry, depth: depth)

                if !entry.children.isEmpty, isExpanded(entry) {
                    VStack(spacing: 0) {
                        ForEach(Array(entry.children.enumerated()), id: \.element.id) { index, child in
                            historyEntryNode(child, depth: depth + 1)

                            if index < entry.children.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                                    .padding(.trailing, 18)
                            }
                        }
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func historyEntryRow(_ entry: HistoryEntry, depth: Int) -> some View {
        let rowFill: Color = entry.allowsStatusToggle
            ? (entry.isDone ? Color.green.opacity(0.07) : Color.red.opacity(0.05))
            : ClockerTheme.Colors.hoverFill.opacity(0.12)

        HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
            Image(systemName: entry.icon)
                .font(ClockerTheme.Fonts.historyIcon)
                .foregroundStyle(ClockerTheme.Colors.rowIcon)
                .frame(width: ClockerTheme.Size.iconWidth, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(ClockerTheme.Fonts.rowLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    if let secondaryText = entry.secondaryText {
                        Text(secondaryText)
                            .font(ClockerTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let accessoryText = entry.accessoryText {
                        if entry.secondaryText != nil {
                            Text("·")
                                .font(ClockerTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(accessoryText)
                            .font(ClockerTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()

            HStack(spacing: 8) {
                if !entry.children.isEmpty {
                    Button {
                        toggleExpansion(for: entry.id)
                    } label: {
                        Image(systemName: isExpanded(entry) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded(entry) ? "Collapse session list" : "Expand session list")
                }

                if let trailingText = entry.trailingText {
                    Text(trailingText)
                        .font(ClockerTheme.Fonts.navTitle)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if entry.allowsStatusToggle, let fileURL = entry.fileURL {
                    Button {
                        toggleStatus(for: fileURL)
                    } label: {
                        statusBadge(isDone: entry.isDone)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.isDone ? "Mark as not done" : "Mark as done")
                }
            }
        }
        .padding(.leading, 18 + CGFloat(depth) * 14)
        .padding(.trailing, 18)
        .padding(.vertical, ClockerTheme.Spacing.rowVertical)
        .background(
            RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                .fill(rowFill)
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

            var nextSections: [HistorySection] = []
            let ignoredRootFileNames: Set<String> = ["projects.json", "state.json"]

            let sortedContents = contents.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
            }

            let rootFiles = sortedContents.filter { fileURL in
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
                return !isDirectory.boolValue && !ignoredRootFileNames.contains(fileURL.lastPathComponent)
            }

            if let rootSection = makeSection(id: ClockProject.defaultID, entries: rootFiles) {
                nextSections.append(rootSection)
            }

            let projectDirectories = sortedContents.filter { fileURL in
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
                return isDirectory.boolValue
            }

            for directory in projectDirectories {
                let directoryEntries = (try? fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []

                let files = directoryEntries
                    .sorted {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
                    }
                    .filter { fileURL in
                        var isDirectory: ObjCBool = false
                        fm.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
                        return !isDirectory.boolValue
                    }

                guard let section = makeSection(id: directory.lastPathComponent, entries: files) else { continue }
                nextSections.append(section)
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

    private func makeSection(id: String, entries: [URL]) -> HistorySection? {
        let result = HistoryDataBuilder.makeResult(
            for: entries,
            mode: viewMode,
            isDone: { [statusStore] fileURL in
                statusStore.isDone(for: fileURL)
            }
        )

        guard !result.entries.isEmpty else { return nil }

        return HistorySection(
            id: id,
            projectName: clockModel.projectName(for: id),
            summaryText: result.summaryText,
            entries: result.entries
        )
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

    private func isExpanded(_ entry: HistoryEntry) -> Bool {
        expandedEntryIDs.contains(entry.id)
    }

    private func toggleExpansion(for entryID: String) {
        if expandedEntryIDs.contains(entryID) {
            expandedEntryIDs.remove(entryID)
        } else {
            expandedEntryIDs.insert(entryID)
        }
    }

    private func toggleStatus(for fileURL: URL) {
        let nextValue = !statusStore.isDone(for: fileURL)
        statusStore.setDone(nextValue, for: fileURL)
        updateStatus(for: fileURL, isDone: nextValue)
    }

    private func updateStatus(for fileURL: URL, isDone: Bool) {
        for sectionIndex in sections.indices {
            guard let entryIndex = sections[sectionIndex].entries.firstIndex(where: { $0.fileURL == fileURL }) else { continue }
            sections[sectionIndex].entries[entryIndex].isDone = isDone
            return
        }
    }
}

enum HistoryDataBuilder {
    struct Bucket: Identifiable {
        let id: Date
        let label: String
        let totalSeconds: Int
        let fileCount: Int
    }

    struct Result {
        let entries: [HistoryEntry]
        let summaryText: String?
    }

    static func makeResult(
        for fileURLs: [URL],
        mode: HistoryViewMode,
        isDone: (URL) -> Bool,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Result {
        switch mode {
        case .files:
            let entries = fileURLs
                .compactMap { makeFileEntry($0, isDone: isDone) }
                .sorted {
                    $0.title.localizedStandardCompare($1.title) == .orderedDescending
                }
            return Result(entries: entries, summaryText: nil)
        case .week, .month:
            let buckets = groupedBuckets(for: fileURLs, mode: mode, calendar: calendar)
            let totalSeconds = buckets.reduce(0) { $0 + $1.totalSeconds }
            let entries = buckets.map { bucket in
                HistoryEntry(
                    id: "\(bucket.id.timeIntervalSince1970)",
                    title: bucket.label,
                    fileURL: nil,
                    secondaryText: bucket.fileCount == 1 ? "1 file" : "\(bucket.fileCount) files",
                    accessoryText: nil,
                    trailingText: formatSummaryDuration(bucket.totalSeconds),
                    icon: "clock.fill",
                    isDone: false,
                    allowsStatusToggle: false,
                    children: []
                )
            }
            return Result(entries: entries, summaryText: formatSummaryDuration(totalSeconds))
        }
    }

    static func groupedBuckets(
        for fileURLs: [URL],
        mode: HistoryViewMode,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Bucket] {
        let snapshots = fileURLs.compactMap { snapshot(for: $0) }
        let grouped = Dictionary(grouping: snapshots) { snapshot in
            bucketStartDate(for: snapshot.date, mode: mode, calendar: calendar)
        }

        return grouped.map { startDate, snapshots in
            Bucket(
                id: startDate,
                label: bucketLabel(for: startDate, mode: mode),
                totalSeconds: snapshots.reduce(0) { $0 + $1.totalSeconds },
                fileCount: snapshots.count
            )
        }
        .sorted { $0.id > $1.id }
    }

    static func formatSummaryDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private struct Snapshot {
        let date: Date
        let totalSeconds: Int
    }

    private static func makeFileEntry(_ fileURL: URL, isDone: (URL) -> Bool) -> HistoryEntry? {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let sessionDurations = ClockModel.parseSessionDurations(from: contents)
        guard !sessionDurations.isEmpty else { return nil }

        let totalSeconds = sessionDurations.reduce(0, +)
        let children = sessionDurations.enumerated().reversed().map { index, duration -> HistoryEntry in
            HistoryEntry(
                id: "\(fileURL.path)#session-\(index)",
                title: "Session \(index + 1)",
                fileURL: nil,
                secondaryText: nil,
                accessoryText: nil,
                trailingText: formatSummaryDuration(duration),
                icon: "clock.fill",
                isDone: false,
                allowsStatusToggle: false,
                children: []
            )
        }

        return HistoryEntry(
            id: fileURL.path,
            title: fileURL.lastPathComponent,
            fileURL: fileURL,
            secondaryText: sessionDurations.count == 1 ? "1 session" : "\(sessionDurations.count) sessions",
            accessoryText: formatSize(values?.fileSize ?? 0),
            trailingText: formatSummaryDuration(totalSeconds),
            icon: iconForFile(fileURL),
            isDone: isDone(fileURL),
            allowsStatusToggle: true,
            children: children
        )
    }

    private static func snapshot(for fileURL: URL) -> Snapshot? {
        let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let totalSeconds = ClockModel.parseSessionDurations(from: contents).reduce(0, +)
        guard totalSeconds > 0 else { return nil }
        let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        let date = fileDateKey(for: fileURL) ?? values?.contentModificationDate ?? Date()
        return Snapshot(date: date, totalSeconds: totalSeconds)
    }

    private static func fileDateKey(for fileURL: URL) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: fileURL.deletingPathExtension().lastPathComponent)
    }

    private static func bucketStartDate(for date: Date, mode: HistoryViewMode, calendar: Calendar) -> Date {
        switch mode {
        case .files:
            return date
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }

    private static func bucketLabel(for date: Date, mode: HistoryViewMode) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        switch mode {
        case .files:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        case .week:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "Week of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    private static func readLastRecord(from contents: String) -> String? {
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.last
    }

    private static func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private static func iconForFile(_ url: URL) -> String {
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
