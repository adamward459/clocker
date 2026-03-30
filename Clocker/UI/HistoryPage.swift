import SwiftUI

struct HistoryPage: View {
    var navigateBack: () -> Void

    private let mockEntries: [(String, String, String)] = [
        ("Today, 09:15 AM", "Started session", "play.circle.fill"),
        ("Today, 08:00 AM", "Opened app", "arrow.up.circle.fill"),
        ("Yesterday, 06:30 PM", "Ended session", "stop.circle.fill"),
        ("Yesterday, 09:00 AM", "Started session", "play.circle.fill"),
        ("Mar 28, 10:45 AM", "Started session", "play.circle.fill"),
        ("Mar 28, 08:30 AM", "Opened app", "arrow.up.circle.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: navigateBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("History")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                // Balance spacer
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13))
                }
                .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(mockEntries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.2)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.1)
                                    .font(.system(size: 13))
                                Text(entry.0)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)

                        if index < mockEntries.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                                .padding(.trailing, 18)
                        }
                    }
                }
                .padding(.vertical, 6)
                .allowsHitTesting(false)
            }
            .frame(maxHeight: 240)
        }
    }
}
