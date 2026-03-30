import SwiftUI

struct MainMenuPage: View {
    @EnvironmentObject var clockModel: ClockModel
    @State private var openAtLogin = false
    var navigateToHistory: () -> Void

    private let iconWidth: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            // Clock header
            VStack(spacing: 6) {
                Text(clockModel.currentTime)
                    .font(.system(size: 40, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                Text(formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.horizontal, 16)

            // Menu rows
            VStack(spacing: 2) {
                // Open at Login
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: iconWidth, alignment: .center)
                        .foregroundStyle(.secondary)
                    Text("Open at Login")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $openAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)

                // History
                Button(action: navigateToHistory) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: iconWidth, alignment: .center)
                            .foregroundStyle(.secondary)
                        Text("History")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.quaternary)
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
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: iconWidth, alignment: .center)
                            .foregroundStyle(.secondary)
                        Text("Quit Clocker")
                        Spacer()
                        Text("⌘Q")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.quaternary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuRowButtonStyle())
                .keyboardShortcut("q")
            }
            .padding(.vertical, 8)
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}
