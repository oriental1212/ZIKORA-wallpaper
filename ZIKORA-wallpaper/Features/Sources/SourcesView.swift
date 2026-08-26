import SwiftUI

private enum SourceFormPresentation: Identifiable {
    case create
    case edit(WallpaperSource)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let source):
            source.id.rawValue.uuidString
        }
    }

    var mode: SourceFormMode {
        switch self {
        case .create:
            .create
        case .edit(let source):
            .edit(source: source)
        }
    }
}

struct SourcesView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: SourcesViewModel?

    var body: some View {
        Group {
            if let model {
                SourcesPageView(environment: environment, model: model)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await prepareModel()
        }
        .navigationTitle("sources.title")
    }

    @MainActor
    private func prepareModel() async {
        guard model == nil, let repository = environment.repository else {
            return
        }
        let viewModel = SourcesViewModel(
            repository: repository,
            clock: environment.clock,
            calendar: environment.calendar,
            uuidGenerator: environment.uuidGenerator,
            sourceFetcher: environment.services?.sourceFetcher ?? UnavailableSourceFetcher()
        )
        model = viewModel
        await viewModel.load()
    }
}

private struct SourcesPageView: View {
    let environment: AppEnvironment
    @ObservedObject var model: SourcesViewModel
    @State private var formPresentation: SourceFormPresentation?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpacing.section) {
                    header
                    sourceList

                    WeeklyPlanSection(
                        plan: model.plan,
                        onUpdateDay: { weekday, sourceID in
                            Task { await model.updateDay(weekday, sourceID: sourceID) }
                        }
                    )

                    DefaultSourceSection(
                        referenceState: model.defaultReferenceState,
                        selectableSources: model.plan?.selectableSources ?? [],
                        onUpdateDefault: { sourceID in
                            Task { await model.updateDefault(sourceID: sourceID) }
                        }
                    )
                }
                .padding(DesignSpacing.section)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .onChange(of: model.focusedSourceID) { _, sourceID in
                guard let sourceID else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(sourceID, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $formPresentation) { presentation in
            if let repository = environment.repository {
                SourceFormSheet(
                    repository: repository,
                    clock: environment.clock,
                    uuidGenerator: environment.uuidGenerator,
                    logger: environment.logger,
                    mode: presentation.mode,
                    onSaved: { sourceID in
                        model.focusSource(id: sourceID)
                        Task { await model.syncNewSource(id: sourceID) }
                    }
                )
            }
        }
        .alert(
            "sources.delete.title",
            isPresented: Binding(
                get: { model.pendingDeletion != nil },
                set: { if !$0 { model.pendingDeletion = nil } }
            ),
            presenting: model.pendingDeletion
        ) { impact in
            Button("sources.delete.confirm", role: .destructive) {
                let sourceID = impact.sourceID
                Task { await model.confirmDelete(sourceID: sourceID) }
            }
            Button("action.cancel", role: .cancel) {
                model.pendingDeletion = nil
            }
        } message: { impact in
            deletionMessage(for: impact)
        }
        .overlay {
            if model.isPreparingDeletion || model.syncingSourceID != nil {
                ProgressView()
                    .controlSize(.small)
                    .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignRadius.card))
            }
        }
        .alert(
            "error.unknown.title",
            isPresented: Binding(
                get: { model.notice != nil },
                set: { if !$0 { model.notice = nil } }
            )
        ) {
            Button("action.cancel") {
                model.notice = nil
            }
        } message: {
            if let notice = model.notice {
                Text(notice.message.detail.rawValue)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    formPresentation = .create
                } label: {
                    Label("sources.add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .help("sources.add.help")
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    Task { await model.load() }
                } label: {
                    Label("sources.refresh", systemImage: "arrow.clockwise")
                }
                .help("sources.refresh.help")

            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text("sources.title")
                .font(DesignTypography.pageTitle)
            Text("sources.subtitle")
                .font(DesignTypography.body)
                .foregroundStyle(DesignColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var sourceList: some View {
        if model.sources.isEmpty {
            EmptyStateView(
                systemImage: "link",
                title: "sources.empty.title",
                message: "sources.empty.message",
                actionTitle: "sources.add",
                action: { formPresentation = .create }
            )
        } else {
            GeometryReader { geometry in
                LazyVGrid(
                    columns: sourceColumns(for: geometry.size.width),
                    alignment: .leading,
                    spacing: DesignSpacing.standard
                ) {
                    ForEach(model.sources, id: \.id) { source in
                        SourceCardView(
                            source: source,
                            isFocused: model.focusedSourceID == source.id,
                            onToggle: { isEnabled in
                                Task { await model.setEnabled(sourceID: source.id, isEnabled: isEnabled) }
                            },
                            onEdit: { formPresentation = .edit(source) },
                            onDelete: {
                                Task { await model.requestDelete(source) }
                            }
                        )
                        .id(source.id)
                    }
                }
            }
            .frame(minHeight: CGFloat(model.sources.count) * 172)
        }
    }

    private func sourceColumns(for width: CGFloat) -> [GridItem] {
        let itemWidth: CGFloat = 420
        let spacing = DesignSpacing.standard
        let count = max(1, Int((width + spacing) / (itemWidth + spacing)))
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: count)
    }

    @ViewBuilder
    private func deletionMessage(for impact: SourceDeletionImpact) -> some View {
        Text("sources.delete.confirm-prefix") + Text(verbatim: "\"\(impact.sourceName)\"")
        if impact.affectedWeekdays.isEmpty {
            Text("sources.delete.no-plan")
        } else {
            Text("sources.delete.affected-weekdays")
                + Text(verbatim: impact.affectedWeekdays.map(\.deletionName).joined(separator: ", "))
        }
        if impact.wasDefaultSource {
            Text("sources.delete.default-unset")
        }
        Text("sources.delete.history-kept")
    }
}
