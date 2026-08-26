import AppKit
import SwiftUI

private struct WallpaperSelection: Identifiable {
    let wallpaper: Wallpaper

    var id: WallpaperID {
        wallpaper.id
    }
}

struct LibraryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: LibraryViewModel?

    var body: some View {
        Group {
            if let model {
                LibraryPageView(environment: environment, model: model)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await prepareModel()
        }
        .navigationTitle("library.title")
    }

    @MainActor
    private func prepareModel() async {
        guard model == nil, let services = environment.services else {
            return
        }
        let viewModel = LibraryViewModel(
            repository: services.repository,
            thumbnailProvider: services.thumbnailProvider,
            fileInventory: services.fileInventory,
            fileStore: services.fileStore,
            finder: services.finder,
            setCurrentWallpaper: services.setCurrentWallpaper,
            managedRootURL: services.managedRootURL,
            randomSelector: environment.randomSelector
        )
        model = viewModel
        await viewModel.load()
    }
}

private struct LibraryPageView: View {
    let environment: AppEnvironment
    @ObservedObject var model: LibraryViewModel
    @State private var selected: WallpaperSelection?
    @State private var pendingDeletion: Wallpaper?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.section) {
                header
                grid
            }
            .padding(DesignSpacing.section)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .overlay {
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignRadius.card))
            }
        }
        .sheet(item: $selected) { selection in
            WallpaperDetailView(
                model: model,
                wallpaper: selection.wallpaper
            )
        }
        .confirmationDialog(
            "library.delete.title",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { wallpaper in
            Button("library.delete.confirm", role: .destructive) {
                Task { await model.delete(wallpaper) }
            }
            Button("action.cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: { wallpaper in
            Text("library.delete.confirm-prefix")
                + Text(verbatim: "\"\(wallpaper.sourceNameSnapshot)\"")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await model.nextWallpaper() }
                } label: {
                    Label("library.next-wallpaper", systemImage: "shuffle")
                }
                .help("library.next-wallpaper.help")
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("library.refresh", systemImage: "arrow.clockwise")
                }
                .help("library.refresh.help")

            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text("library.title")
                .font(DesignTypography.pageTitle)
            Text("library.subtitle")
                .font(DesignTypography.body)
                .foregroundStyle(DesignColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSpacing.small) {
                TextField("library.search", text: searchBinding)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, DesignSpacing.standard)
                    .padding(.vertical, DesignSpacing.medium)
                    .background(DesignColor.glassSurface, in: Capsule())
                    .overlay { Capsule().stroke(DesignColor.glassBorder, lineWidth: 1) }
                    .frame(width: 300)
                    .onSubmit { model.submitSearch() }
                Button("action.search", systemImage: "magnifyingglass") { model.submitSearch() }
                    .buttonStyle(.borderedProminent)
                Button("action.reset", systemImage: "arrow.counterclockwise") { model.resetSearch() }
                    .disabled(model.searchText.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        if model.wallpapers.isEmpty {
            EmptyStateView(
                systemImage: "photo.on.rectangle",
                title: "library.empty.title",
                message: "library.empty.message",
                actionTitle: "library.refresh",
                action: { Task { await model.refresh() } }
            )
        } else if model.filteredWallpapers.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "library.no-results.title",
                message: "library.no-results.message",
                actionTitle: "library.clear-filter",
                action: { model.resetSearch() }
            )
        } else {
            GeometryReader { geometry in
                LazyVGrid(columns: libraryColumns(for: geometry.size.width), alignment: .leading, spacing: DesignSpacing.standard * 2) {
                    ForEach(model.filteredWallpapers, id: \.id) { wallpaper in
                        Button {
                            selected = WallpaperSelection(wallpaper: wallpaper)
                        } label: {
                            WallpaperCellView(
                                wallpaper: wallpaper,
                                thumbnailProvider: model.thumbnailProvider,
                                request: model.thumbnailRequest(for: wallpaper, size: ThumbnailSize(width: 320, height: 200)),
                                isCurrent: wallpaper.isCurrent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: CGFloat(model.filteredWallpapers.count) * 280)
        }
    }

    private func libraryColumns(for width: CGFloat) -> [GridItem] {
        let itemWidth: CGFloat = 250
        let spacing = DesignSpacing.standard * 2
        let count = max(1, Int((width + spacing) / (itemWidth + spacing)))
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: count)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { model.searchText },
            set: { model.setSearchText($0) }
        )
    }
}

private struct WallpaperCellView: View {
    let wallpaper: Wallpaper
    let thumbnailProvider: any ThumbnailProviding
    let request: ThumbnailRequest?
    let isCurrent: Bool

    @State private var thumbnailState: WallpaperThumbnailState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            WallpaperThumbnail(
                state: thumbnailState,
                accessibilityLabel: "library.thumbnail"
            )
            .overlay(alignment: .topTrailing) {
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, DesignColor.primaryAction)
                        .padding(DesignSpacing.compact)
                        .accessibilityLabel("library.current")
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                    .stroke(
                        isCurrent ? DesignColor.primaryAction : DesignColor.separator,
                        lineWidth: isCurrent ? 2 : 1
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.sourceNameSnapshot)
                    .font(DesignTypography.label)
                    .lineLimit(1)
                Text(wallpaper.downloadDay.rawValue)
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColor.secondaryText)
                fileStateLabel
            }
        }
        .padding(DesignSpacing.small)
        .designSurface(.card)
        .task(id: wallpaper.id) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var fileStateLabel: some View {
        switch wallpaper.fileState {
        case .available:
            EmptyView()
        case .missing:
            Label("library.file-missing", systemImage: "questionmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.warning)
        case .invalid:
            Label("library.file-invalid", systemImage: "exclamationmark.triangle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.critical)
        }
    }

    @MainActor
    private func loadThumbnail() async {
        guard let request else {
            thumbnailState = .unavailable
            return
        }
        thumbnailState = .loading
        do {
            let url = try await thumbnailProvider.thumbnail(for: request)
            guard !Task.isCancelled else { return }
            if let image = NSImage(contentsOf: url) {
                thumbnailState = .available(Image(nsImage: image))
            } else {
                thumbnailState = .unavailable
            }
        } catch {
            guard !Task.isCancelled else { return }
            thumbnailState = .unavailable
        }
    }
}

private struct WallpaperDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: LibraryViewModel
    let wallpaper: Wallpaper
    @State private var deleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.large) {
            Button { dismiss() } label: {
                Label("action.back", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text("library.detail.title")
                .font(DesignTypography.pageTitle)

            AsyncImage(url: model.fileURL(for: wallpaper)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignColor.secondaryText)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))

            metadata

            HStack(spacing: DesignSpacing.small) {
                ZIKORAButton(
                    "library.set-current",
                    systemImage: "desktopcomputer",
                    role: .primary,
                    disabledReason: wallpaper.fileState == .available
                        ? nil
                        : "library.file-unavailable",
                    action: {
                        Task {
                            await model.setCurrent(wallpaper)
                            dismiss()
                        }
                    }
                )

                Button("library.reveal", systemImage: "folder") {
                    Task { await model.reveal(wallpaper) }
                }

                Spacer()

                ZIKORAButton(
                    "library.delete",
                    systemImage: "trash",
                    role: .destructive,
                    disabledReason: wallpaper.isCurrent ? "library.current-delete-disabled" : nil,
                    action: { deleteConfirmation = true }
                )
            }
        }
        .padding(DesignSpacing.large)
        .frame(width: 720)
        .confirmationDialog(
            "library.delete.title",
            isPresented: $deleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("library.delete.confirm", role: .destructive) {
                Task {
                    await model.delete(wallpaper)
                    dismiss()
                }
            }
            Button("action.cancel", role: .cancel) { }
        } message: {
            Text("library.delete.confirm-prefix")
                + Text(verbatim: "\"\(wallpaper.sourceNameSnapshot)\"")
        }
    }

    private var metadata: some View {
        Grid(alignment: .leading, horizontalSpacing: DesignSpacing.large) {
            GridRow {
                metadataLabel("library.source")
                Text(wallpaper.sourceNameSnapshot)
            }
            GridRow {
                metadataLabel("library.download-day")
                Text(wallpaper.downloadDay.rawValue)
            }
            GridRow {
                metadataLabel("library.size")
                Text("\(wallpaper.pixelWidth) × \(wallpaper.pixelHeight)")
            }
            GridRow {
                metadataLabel("library.format")
                Text(wallpaper.format.rawValue.uppercased())
            }
            GridRow {
                metadataLabel("library.file-size")
                Text(ByteCountFormatter.sourcePreview.string(fromByteCount: wallpaper.fileSize))
            }
            GridRow {
                metadataLabel("library.path")
                Text(verbatim: model.fileURL(for: wallpaper).path)
                    .font(DesignTypography.monospacedMetadata)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func metadataLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(DesignTypography.label)
            .foregroundStyle(DesignColor.secondaryText)
    }
}
