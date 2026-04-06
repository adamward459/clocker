import SwiftUI

enum HistoryViewMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
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
    let secondaryText: String?
    let accessoryText: String?
    let trailingText: String?
    let icon: String
    var children: [HistoryEntry]

    init(
        id: String = UUID().uuidString,
        title: String,
        secondaryText: String? = nil,
        accessoryText: String? = nil,
        trailingText: String? = nil,
        icon: String,
        children: [HistoryEntry] = []
    ) {
        self.id = id
        self.title = title
        self.secondaryText = secondaryText
        self.accessoryText = accessoryText
        self.trailingText = trailingText
        self.icon = icon
        self.children = children
    }
}

struct HistorySection: Identifiable {
    let id: UUID
    let projectName: String
    var summaryText: String?
    var entries: [HistoryEntry]
}

struct HistoryPage: View {
    static let viewModeStorageKey = "history.viewMode"
    static let preferredWidth: CGFloat = 400

    @EnvironmentObject var clockService: ClockService
    @AppStorage(Self.viewModeStorageKey) private var viewModeRawValue = HistoryViewMode.week.rawValue

    var navigateBack: () -> Void
    var isVisible: Bool = false
    @State private var backHovered = false
    @State private var sections: [HistorySection] = []
    @State private var expandedEntryIDs: Set<String> = []

    private var viewMode: HistoryViewMode {
        get { HistoryViewMode(rawValue: viewModeRawValue) ?? .week }
        set { viewModeRawValue = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            if sections.isEmpty {
                emptyState(icon: "folder.badge.questionmark", message: "No sessions found")
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
        .onChange(of: clockService.dataRevision) { _, _ in
            if isVisible { loadEntries() }
        }
        .onChange(of: clockService.displayTime) { _, _ in
            if isVisible { loadEntries() }
        }
        .frame(width: Self.preferredWidth)
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
        let rowFill: Color = entry.children.isEmpty
            ? ClockerTheme.Colors.hoverFill.opacity(0.12)
            : ClockerTheme.Colors.hoverFill.opacity(0.18)

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
        var nextSections: [HistorySection] = []

        for project in clockService.orderedProjects {
            let sessions = clockService.sessions(for: project.id)
            guard let section = makeSection(project: project, sessions: sessions) else { continue }
            nextSections.append(section)
        }

        sections = nextSections
    }

    private func makeSection(project: Project, sessions: [Session]) -> HistorySection? {
        let result = HistoryDataBuilder.makeResult(for: sessions, mode: viewMode)
        guard !result.entries.isEmpty else { return nil }

        return HistorySection(
            id: project.id,
            projectName: project.name,
            summaryText: result.summaryText,
            entries: result.entries
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
            .fill(ClockerTheme.Colors.hoverFill.opacity(0.25))
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
}

enum HistoryDataBuilder {
    struct Bucket: Identifiable {
        let id: Date
        let label: String
        let totalSeconds: Int
        let sessionCount: Int
        let sessions: [Session]
    }

    struct Result {
        let entries: [HistoryEntry]
        let summaryText: String?
    }

    static func makeResult(
        for sessions: [Session],
        mode: HistoryViewMode,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Result {
        switch mode {
        case .week, .month:
            let buckets = groupedBuckets(for: sessions, mode: mode, calendar: calendar)
            let totalSeconds = buckets.reduce(0) { $0 + $1.totalSeconds }
            let entries = buckets.map { bucket in
                HistoryEntry(
                    id: "bucket-\(bucket.id.timeIntervalSince1970)",
                    title: bucket.label,
                    secondaryText: bucket.sessionCount == 1 ? "1 session" : "\(bucket.sessionCount) sessions",
                    trailingText: formatSummaryDuration(bucket.totalSeconds),
                    icon: "clock.fill",
                    children: bucket.sessions
                        .sorted { $0.createdAt > $1.createdAt }
                        .compactMap(makeSessionEntry(_:))
                )
            }
            return Result(entries: entries, summaryText: formatSummaryDuration(totalSeconds))
        }
    }

    static func groupedBuckets(
        for sessions: [Session],
        mode: HistoryViewMode,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Bucket] {
        let snapshots = sessions.compactMap { snapshot(for: $0) }
        let grouped = Dictionary(grouping: snapshots) { snapshot in
            bucketStartDate(for: snapshot.date, mode: mode, calendar: calendar)
        }

        return grouped.map { startDate, snapshots in
            Bucket(
                id: startDate,
                label: bucketLabel(for: startDate, mode: mode),
                totalSeconds: snapshots.reduce(0) { $0 + $1.totalSeconds },
                sessionCount: snapshots.count,
                sessions: snapshots.map(\.session)
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
        let session: Session
    }

    private static func makeSessionEntry(_ session: Session) -> HistoryEntry? {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let statusText: String
        switch session.status {
        case .running:
            statusText = "Running"
        case .done:
            statusText = "Done"
        case .undone:
            statusText = "Undone"
        }

        return HistoryEntry(
            id: session.id.uuidString,
            title: formatter.string(from: session.createdAt),
            secondaryText: session.dateKey,
            accessoryText: statusText,
            trailingText: formatSummaryDuration(session.currentElapsedSeconds),
            icon: "clock.fill"
        )
    }

    private static func snapshot(for session: Session) -> Snapshot? {
        let date = dateFromKey(session.dateKey) ?? session.createdAt
        return Snapshot(date: date, totalSeconds: session.currentElapsedSeconds, session: session)
    }

    private static func dateFromKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private static func bucketStartDate(for date: Date, mode: HistoryViewMode, calendar: Calendar) -> Date {
        switch mode {
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
        case .week:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "Week of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}
