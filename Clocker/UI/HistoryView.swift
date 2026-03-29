import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: ClockStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.title2.weight(.semibold))

                    Text("Review today's progress and previous saved days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                SyncStatusView(state: store.syncState, emphasis: .compact)
            }
            .padding(.horizontal, 2)

            summaryStrip

            List {
                Section {
                    recordRow(for: store.todayRecord, isToday: true)
                } header: {
                    sectionHeader("Today", systemImage: "sun.max.fill")
                }

                Section {
                    if store.pastRecords.isEmpty {
                        ContentUnavailableView(
                            "No saved days yet",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Once you track time across days, your archive will appear here.")
                        )
                    } else {
                        ForEach(store.pastRecords) { record in
                            recordRow(for: record, isToday: false)
                        }
                    }
                } header: {
                    sectionHeader("Past Days", systemImage: "calendar")
                }
            }
            .listStyle(.inset)
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 460)
        .task {
            await store.refreshHistory()
        }
    }

    @ViewBuilder
    private func recordRow(for record: DailyRecord, isToday: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isToday ? "record.circle.fill" : "calendar.circle.fill")
                .font(.title3)
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(isToday ? "Today" : DateKey.displayString(from: record.dateKey))
                    .font(.body.weight(.medium))
                Text(record.dateKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(DurationFormatter.string(from: record.elapsedSeconds))
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summaryTile(
                title: "Today",
                value: store.formattedElapsed,
                systemImage: "timer",
                accent: .accentColor
            )
            summaryTile(
                title: "Saved Days",
                value: "\(store.pastRecords.count)",
                systemImage: "archivebox.fill",
                accent: .blue
            )
        }
    }

    private func summaryTile(
        title: String,
        value: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}
