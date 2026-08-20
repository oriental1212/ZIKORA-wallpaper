import SwiftUI

enum StatusBadgeKind {
    case information
    case success
    case warning
    case failure
    case disabled

    var color: Color {
        switch self {
        case .information:
            DesignColor.primaryAction
        case .success:
            DesignColor.success
        case .warning:
            DesignColor.warning
        case .failure:
            DesignColor.critical
        case .disabled:
            DesignColor.secondaryText
        }
    }

    var systemImage: String {
        switch self {
        case .information:
            "info.circle"
        case .success:
            "checkmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .failure:
            "xmark.octagon"
        case .disabled:
            "pause.circle"
        }
    }
}

struct StatusBadge: View {
    let title: LocalizedStringKey
    let kind: StatusBadgeKind

    var body: some View {
        Label(title, systemImage: kind.systemImage)
            .font(DesignTypography.caption.weight(.semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.vertical, DesignSpacing.compact)
            .background(kind.color.opacity(0.1), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
