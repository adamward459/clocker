import SwiftUI

enum ClockerTheme {
    // MARK: - Spacing
    enum Spacing {
        static let rowHorizontal: CGFloat = 12
        static let rowVertical: CGFloat = 7
        static let rowOuterPadding: CGFloat = 6
        static let sectionPadding: CGFloat = 18
        static let iconTextGap: CGFloat = 10
        static let sectionGap: CGFloat = 8
    }

    // MARK: - Sizing
    enum Size {
        static let iconWidth: CGFloat = 20
        static let popoverWidth: CGFloat = 336
        static let cornerRadius: CGFloat = 8
        static let historyMaxHeight: CGFloat = 260
    }

    // MARK: - Fonts
    enum Fonts {
        static let clockDisplay = Font.system(size: 40, weight: .ultraLight, design: .rounded)
        static let dateLabel = Font.system(size: 12, weight: .medium)
        static let rowLabel = Font.system(size: 13)
        static let rowIcon = Font.system(size: 12, weight: .medium)
        static let caption = Font.system(size: 11)
        static let chevron = Font.system(size: 10, weight: .semibold)
        static let shortcut = Font.system(size: 11, design: .rounded)
        static let navTitle = Font.system(size: 13, weight: .semibold)
        static let navBack = Font.system(size: 13)
        static let navBackIcon = Font.system(size: 12, weight: .semibold)
        static let historyIcon = Font.system(size: 14)
    }

    // MARK: - Colors
    enum Colors {
        static let hoverFill = Color.primary.opacity(0.05)
        static let pressFill = Color.accentColor.opacity(0.12)
        static let rowIcon = Color.secondary
        static let trailingAccessory = Color.primary.opacity(0.24)
    }

    // MARK: - Animation
    enum Animation {
        static let pageSlide = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}
