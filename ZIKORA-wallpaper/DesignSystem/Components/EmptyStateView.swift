import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DesignColor.secondaryText)
                .accessibilityHidden(true)

            Text(title)
                .font(DesignTypography.sectionTitle)

            Text(message)
                .font(DesignTypography.body)
                .foregroundStyle(DesignColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                ZIKORAButton(actionTitle, role: .primary, action: action)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(DesignSpacing.large)
        .designSurface(.card)
    }
}
