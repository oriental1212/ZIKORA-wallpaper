import SwiftUI

private enum DefaultSourceSelection: Hashable {
    case unset
    case source(SourceID)
}

struct DefaultSourceSection: View {
    let referenceState: WeeklyPlanReferenceState
    let selectableSources: [WeeklyPlanSourceOption]
    let onUpdateDefault: (SourceID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            VStack(alignment: .leading, spacing: DesignSpacing.compact) {
                Text("sources.default.title")
                    .font(DesignTypography.sectionTitle)
                Text("sources.default.description")
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSpacing.standard) {
                    referenceWarning
                    Spacer()
                    picker
                }

                VStack(alignment: .leading, spacing: DesignSpacing.small) {
                    referenceWarning
                    picker
                }
            }
            .padding(DesignSpacing.standard)
            .designSurface(.card)
        }
    }

    private var picker: some View {
        Picker("sources.default.picker", selection: selectionBinding) {
            Text("sources.default.unset")
                .tag(DefaultSourceSelection.unset)
            ForEach(selectableSources, id: \.id) { option in
                Text(option.name)
                    .tag(DefaultSourceSelection.source(option.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 220, alignment: .leading)
    }

    private var selectionBinding: Binding<DefaultSourceSelection> {
        Binding(
            get: {
                switch referenceState {
                case .available(let sourceID, _):
                    .source(sourceID)
                case .unset, .disabled, .missing:
                    .unset
                }
            },
            set: { value in
                switch value {
                case .unset:
                    onUpdateDefault(nil)
                case .source(let sourceID):
                    onUpdateDefault(sourceID)
                }
            }
        )
    }

    @ViewBuilder
    private var referenceWarning: some View {
        switch referenceState {
        case .disabled(let sourceID, let name):
            Label {
                Text(name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(DesignTypography.caption)
            .foregroundStyle(DesignColor.warning)
            .help("sources.default.disabled-warning")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("sources.default.disabled-warning")
            .accessibilityValue(sourceID.rawValue.uuidString)
        case .missing:
            Label("sources.default.missing-warning", systemImage: "questionmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.warning)
        case .unset, .available:
            EmptyView()
        }
    }
}
