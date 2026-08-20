import AppKit
import SwiftUI

struct SourceCardView: View {
    let source: WallpaperSource
    let isFocused: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var copied = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .padding(DesignSpacing.large)
        .frame(width: 420, height: 156, alignment: .leading)
        .designSurface(.card)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                    .stroke(DesignColor.focus, lineWidth: 2)
            }
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: DesignSpacing.standard) {
            icon
            titleBlock

            Spacer(minLength: DesignSpacing.medium)

            toggle
            editDeleteControls
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            HStack(alignment: .center, spacing: DesignSpacing.standard) {
                icon
                titleBlock
                Spacer(minLength: DesignSpacing.small)
                toggle
            }

            HStack(spacing: DesignSpacing.medium) {
                Spacer(minLength: DesignSpacing.small)
                editDeleteControls
            }
        }
    }

    private var icon: some View {
        Image(systemName: "link")
            .font(.title2)
            .foregroundStyle(DesignColor.primaryAction)
            .frame(width: 44, height: 44)
            .background(
                DesignColor.primaryAction.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: DesignRadius.control,
                    style: .continuous
                )
            )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(source.name)
                .font(DesignTypography.sectionTitle)
                .lineLimit(1)

            HStack(spacing: DesignSpacing.small) {
                SourceStatusView(source: source)
                syncTime
            }

            copyURLButton
        }
    }

    private var toggle: some View {
        Toggle(
            "sources.enabled",
            isOn: Binding(
                get: { source.isEnabled },
                set: { onToggle($0) }
            )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(DesignColor.primaryAction)
        .help(source.isEnabled ? "sources.disable.help" : "sources.enable.help")
        .accessibilityLabel(source.isEnabled ? "sources.disable.help" : "sources.enable.help")
    }

    private var editDeleteControls: some View {
        HStack(spacing: DesignSpacing.compact) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("sources.edit")
            .accessibilityLabel("sources.edit")

            Button(action: onDelete) {
                Label("sources.delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(DesignColor.critical)
            .help("sources.delete")
            .accessibilityLabel("sources.delete")
        }
    }

    private var syncTime: some View {
        Group {
            if let lastFetchAt = source.lastFetchAt {
                Text(lastFetchAt.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text("sources.last-sync.never")
            }
        }
        .font(DesignTypography.caption)
        .foregroundStyle(DesignColor.secondaryText)
        .accessibilityLabel("sources.last-sync")
    }

    private var copyURLButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(source.url.absoluteString, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            HStack(spacing: DesignSpacing.compact) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? DesignColor.success : DesignColor.secondaryText)
                Text(verbatim: URLRedactor.redact(source.url))
                    .font(DesignTypography.monospacedMetadata)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(DesignColor.secondaryText)
                if copied {
                    Text("sources.copied")
                        .font(DesignTypography.caption)
                        .foregroundStyle(DesignColor.success)
                }
            }
        }
        .buttonStyle(.plain)
        .help("sources.copy-url")
        .accessibilityLabel("sources.copy-url")
    }
}
