import SwiftUI

private enum WeeklyPlanSelection: Hashable {
    case unset
    case source(SourceID)
}

struct WeeklyPlanSection: View {
    let plan: WeeklyPlanSnapshot?
    let onUpdateDay: (Weekday, SourceID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.medium) {
            VStack(alignment: .leading, spacing: DesignSpacing.compact) {
                Text("sources.weekly-plan.title")
                    .font(DesignTypography.sectionTitle)
                Text("sources.weekly-plan.description")
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let plan {
                VStack(spacing: 0) {
                    ForEach(plan.rows, id: \.weekday) { row in
                        WeeklyPlanRowView(
                            row: row,
                            options: plan.selectableSources,
                            onUpdate: { sourceID in
                                onUpdateDay(row.weekday, sourceID)
                            }
                        )

                        if row.weekday != .sunday {
                            Divider()
                        }
                    }
                }
                .designSurface(.card)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

private struct WeeklyPlanRowView: View {
    let row: WeeklyPlanRow
    let options: [WeeklyPlanSourceOption]
    let onUpdate: (SourceID?) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignSpacing.standard) {
                dayLabel
                Spacer(minLength: DesignSpacing.medium)
                referenceWarning
                picker
            }

            VStack(alignment: .leading, spacing: DesignSpacing.small) {
                HStack(spacing: DesignSpacing.small) {
                    dayLabel
                    Spacer(minLength: DesignSpacing.small)
                    referenceWarning
                }
                picker
            }
        }
        .padding(.horizontal, DesignSpacing.standard)
        .padding(.vertical, DesignSpacing.small)
        .frame(minHeight: 40)
    }

    private var dayLabel: some View {
        HStack(spacing: DesignSpacing.small) {
            Text(row.weekday.localizedTitle)
                .font(DesignTypography.label)
                .frame(minWidth: 72, alignment: .leading)
            if row.isToday {
                Text("weekday.today")
                    .font(DesignTypography.caption.weight(.semibold))
                    .foregroundStyle(DesignColor.primaryAction)
                    .padding(.horizontal, DesignSpacing.small)
                    .padding(.vertical, 2)
                    .background(DesignColor.primaryAction.opacity(0.1), in: Capsule())
            }
        }
    }

    private var picker: some View {
        Picker("sources.weekly-plan.picker", selection: selectionBinding) {
            Text("sources.weekly-plan.unset")
                .tag(WeeklyPlanSelection.unset)
            ForEach(options, id: \.id) { option in
                Text(option.name)
                    .tag(WeeklyPlanSelection.source(option.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 220, alignment: .leading)
    }

    private var selectionBinding: Binding<WeeklyPlanSelection> {
        Binding(
            get: {
                switch row.referenceState {
                case .available(let sourceID, _):
                    .source(sourceID)
                case .unset, .disabled, .missing:
                    .unset
                }
            },
            set: { value in
                switch value {
                case .unset:
                    onUpdate(nil)
                case .source(let sourceID):
                    onUpdate(sourceID)
                }
            }
        )
    }

    @ViewBuilder
    private var referenceWarning: some View {
        switch row.referenceState {
        case .disabled(let sourceID, let name):
            Label {
                Text(name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(DesignTypography.caption)
            .foregroundStyle(DesignColor.warning)
            .help("sources.weekly-plan.disabled-warning")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("sources.weekly-plan.disabled-warning")
            .accessibilityValue(sourceID.rawValue.uuidString)
        case .missing:
            Label("sources.weekly-plan.missing-warning", systemImage: "questionmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.warning)
        case .unset, .available:
            EmptyView()
        }
    }
}
