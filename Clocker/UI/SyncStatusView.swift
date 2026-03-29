import SwiftUI

enum SyncStatusEmphasis {
    case compact
    case prominent
}

struct SyncStatusView: View {
    let state: SyncState
    var emphasis: SyncStatusEmphasis = .compact

    var body: some View {
        Group {
            switch emphasis {
            case .compact:
                Label {
                    Text(state.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: state.symbolName)
                        .foregroundStyle(state.color)
                }
                .labelStyle(.titleAndIcon)
            case .prominent:
                Label(state.title, systemImage: state.symbolName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(state.color.opacity(0.14))
                    .foregroundStyle(state.color)
                    .clipShape(Capsule())
            }
        }
    }
}
