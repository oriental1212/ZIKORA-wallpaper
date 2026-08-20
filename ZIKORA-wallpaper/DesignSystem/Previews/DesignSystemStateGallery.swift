import SwiftUI

struct DesignSystemStateGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.large) {
                Text("design-system.preview.title")
                    .font(DesignTypography.pageTitle)

                stateRow("state.default") {
                    ZIKORAButton("action.update-now", systemImage: "arrow.clockwise") {}
                }
                stateRow("state.hover") {
                    ZIKORAButton("action.update-now", systemImage: "arrow.clockwise") {}
                        .help("state.hover.help")
                }
                stateRow("state.focus") {
                    ZIKORAButton("action.update-now", systemImage: "arrow.clockwise") {}
                        .help("state.focus.help")
                }
                stateRow("state.active") {
                    ZIKORAButton("action.update-now", systemImage: "arrow.clockwise") {}
                        .help("state.active.help")
                }
                stateRow("state.disabled") {
                    ZIKORAButton(
                        "action.update-now",
                        disabledReason: "state.disabled.reason"
                    ) {}
                }
                stateRow("state.loading") {
                    ZIKORAButton("action.update-now", phase: .loading) {}
                }
                stateRow("state.error") {
                    ZIKORAButton("action.retry", phase: .failure) {}
                }
                stateRow("state.success") {
                    ZIKORAButton("action.update-now", phase: .success) {}
                }

                HStack(spacing: DesignSpacing.small) {
                    StatusBadge(title: "status.success", kind: .success)
                    StatusBadge(title: "status.warning", kind: .warning)
                    StatusBadge(title: "status.failed", kind: .failure)
                }
            }
            .padding(DesignSpacing.section)
        }
        .frame(width: 620, height: 720)
        .background(DesignColor.background)
    }

    private func stateRow<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: DesignSpacing.large) {
            Text(title)
                .font(DesignTypography.label)
                .frame(width: 100, alignment: .leading)
            content()
        }
    }
}

#Preview("Design System — 8 states") {
    DesignSystemStateGallery()
}
