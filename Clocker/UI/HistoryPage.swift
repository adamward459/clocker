import SwiftUI

struct HistoryPage: View {
    var navigateBack: () -> Void
    @State private var backHovered = false

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

                // Balance spacer
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

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(mockEntries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: ClockerTheme.Spacing.iconTextGap) {
                            Image(systemName: entry.2)
                                .font(ClockerTheme.Fonts.historyIcon)
                                .foregroundStyle(ClockerTheme.Colors.rowIcon)
                                .frame(width: ClockerTheme.Size.iconWidth, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.1)
                                    .font(ClockerTheme.Fonts.rowLabel)
                                Text(entry.0)
                                    .font(ClockerTheme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, ClockerTheme.Spacing.rowVertical)

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
            .frame(maxHeight: ClockerTheme.Size.historyMaxHeight)
        }
    }
}
