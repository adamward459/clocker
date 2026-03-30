import SwiftUI

struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRowButtonBody(configuration: configuration)
    }
}

private struct MenuRowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    private var background: Color {
        if configuration.isPressed {
            return ClockerTheme.Colors.pressFill
        } else if isHovered {
            return ClockerTheme.Colors.hoverFill
        }
        return .clear
    }

    var body: some View {
        configuration.label
            .font(ClockerTheme.Fonts.rowLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ClockerTheme.Spacing.rowHorizontal)
            .padding(.vertical, ClockerTheme.Spacing.rowVertical)
            .background(
                RoundedRectangle(cornerRadius: ClockerTheme.Size.cornerRadius, style: .continuous)
                    .fill(background)
            )
            .padding(.horizontal, ClockerTheme.Spacing.rowOuterPadding)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
