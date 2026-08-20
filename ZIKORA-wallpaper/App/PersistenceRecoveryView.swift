import SwiftUI

struct PersistenceRecoveryView: View {
    let message: UserMessage
    let retry: () -> Void
    let archiveAndStartFresh: () -> Void
    @State private var confirmsFreshStore = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            StatusBadge(
                title: LocalizedStringKey(message.title.rawValue),
                kind: .failure
            )
            Text("persistence.recovery.detail")
                .font(DesignTypography.body)
            HStack {
                ZIKORAButton(
                    "action.retry",
                    systemImage: "arrow.clockwise",
                    role: .primary,
                    action: retry
                )
                ZIKORAButton(
                    "action.start-fresh",
                    systemImage: "archivebox",
                    role: .secondary
                ) {
                    confirmsFreshStore = true
                }
            }
        }
        .padding(DesignSpacing.large)
        .frame(maxWidth: 520)
        .designSurface(.card)
        .confirmationDialog(
            "persistence.recovery.confirm-title",
            isPresented: $confirmsFreshStore
        ) {
            Button("action.start-fresh", role: .destructive, action: archiveAndStartFresh)
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("persistence.recovery.confirm-detail")
        }
    }
}
