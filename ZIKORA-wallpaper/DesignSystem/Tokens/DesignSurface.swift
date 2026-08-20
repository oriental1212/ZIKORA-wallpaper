import SwiftUI

enum DesignSurfaceRole {
    case sidebar
    case toolbar
    case card
}

private struct DesignSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let role: DesignSurfaceRole

    func body(content: Content) -> some View {
        content
            .background {
                background
            }
            .overlay {
                if role == .card || contrast == .increased {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            role == .card ? DesignColor.glassBorder : DesignColor.separator,
                            lineWidth: contrast == .increased ? 2 : 1
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(role == .card ? DesignColor.surface : DesignColor.elevatedSurface)
        } else if role == .card {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DesignColor.glassSurface)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(role == .sidebar ? .thinMaterial : .bar)
                .overlay {
                    if role == .sidebar {
                        DesignColor.primaryAction.opacity(0.04)
                    }
                }
        }
    }

    private var cornerRadius: CGFloat {
        role == .card ? DesignRadius.card : DesignRadius.control
    }
}

extension View {
    func designSurface(_ role: DesignSurfaceRole) -> some View {
        modifier(DesignSurfaceModifier(role: role))
    }
}
