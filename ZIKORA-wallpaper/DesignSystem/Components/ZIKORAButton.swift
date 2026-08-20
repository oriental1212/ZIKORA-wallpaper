import SwiftUI

enum ZIKORAButtonRole {
    case primary
    case secondary
    case destructive
}

enum ZIKORAButtonPhase: Equatable {
    case idle
    case loading
    case success
    case failure

    var statusKey: LocalizedStringKey? {
        switch self {
        case .idle:
            nil
        case .loading:
            "status.loading"
        case .success:
            "status.success"
        case .failure:
            "status.failed"
        }
    }

    var systemImage: String? {
        switch self {
        case .idle, .loading:
            nil
        case .success:
            "checkmark"
        case .failure:
            "exclamationmark.triangle"
        }
    }
}

struct ZIKORAButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: LocalizedStringKey
    let systemImage: String?
    let role: ZIKORAButtonRole
    let phase: ZIKORAButtonPhase
    let disabledReason: LocalizedStringKey?
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        role: ZIKORAButtonRole = .primary,
        phase: ZIKORAButtonPhase = .idle,
        disabledReason: LocalizedStringKey? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.phase = phase
        self.disabledReason = disabledReason
        self.action = action
    }

    var body: some View {
        Group {
            switch role {
            case .primary:
                button
                    .buttonStyle(.borderedProminent)
                    .tint(phase == .failure ? DesignColor.critical : DesignColor.primaryAction)
            case .secondary:
                button
                    .buttonStyle(.bordered)
            case .destructive:
                button
                    .buttonStyle(.borderedProminent)
                    .tint(DesignColor.critical)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .disabled(disabledReason != nil || phase == .loading)
        .help(disabledReason ?? title)
        .accessibilityValue(accessibilityValue)
        .animation(DesignMotion.stateChange(reduceMotion: reduceMotion), value: phase)
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.small) {
                if phase == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else if let icon = phase.systemImage ?? systemImage {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                }

                Text(phase.statusKey ?? title)
                    .lineLimit(1)
            }
            .font(DesignTypography.label)
        }
    }

    private var accessibilityValue: Text {
        switch phase {
        case .idle:
            Text(title)
        case .loading:
            Text("status.loading")
        case .success:
            Text("status.success")
        case .failure:
            Text("status.failed")
        }
    }
}
