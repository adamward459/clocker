import SwiftUI

enum SyncState: String, Sendable {
    case localOnly
    case savingToFolder
    case folderSelected

    var title: String {
        switch self {
        case .localOnly:
            return "Local Only"
        case .savingToFolder:
            return "Saving"
        case .folderSelected:
            return "Folder Selected"
        }
    }

    var color: Color {
        switch self {
        case .folderSelected:
            return .green
        case .savingToFolder:
            return .orange
        case .localOnly:
            return .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .folderSelected:
            return "checkmark.circle.fill"
        case .savingToFolder:
            return "arrow.down.circle.fill"
        case .localOnly:
            return "internaldrive"
        }
    }
}
