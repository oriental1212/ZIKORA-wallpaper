import SwiftUI

enum AsyncContentState<Value> {
    case idle
    case loading
    case empty
    case failure(UserMessage)
    case loaded(Value)
}

struct AsyncContent<Value, Content: View>: View {
    let state: AsyncContentState<Value>
    let retry: (() -> Void)?
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("status.loading")
                .controlSize(.small)
        case .empty:
            EmptyStateView(
                systemImage: "photo.on.rectangle.angled",
                title: "empty.generic.title",
                message: "empty.generic.message"
            )
        case .failure(let message):
            failureView(message)
        case .loaded(let value):
            content(value)
        }
    }

    private func failureView(_ message: UserMessage) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            StatusBadge(title: localizedKey(message.title), kind: .failure)
            Text(localizedKey(message.detail))
                .font(DesignTypography.body)
            if let retry {
                ZIKORAButton("action.retry", systemImage: "arrow.clockwise", role: .secondary, action: retry)
            }
        }
        .padding(DesignSpacing.large)
        .designSurface(.card)
    }

    private func localizedKey(_ key: UserMessageKey) -> LocalizedStringKey {
        LocalizedStringKey(key.rawValue)
    }
}
