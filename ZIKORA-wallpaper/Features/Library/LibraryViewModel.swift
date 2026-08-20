import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var wallpapers: [Wallpaper] = []
    @Published private(set) var filteredWallpapers: [Wallpaper] = []
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var selectedWallpaper: Wallpaper?
    @Published var notice: OperationNotice?

    private let repository: any WallpaperRepository
    let thumbnailProvider: any ThumbnailProviding
    private let fileInventory: any ManagedFileInventoryProviding
    private let fileStore: any WallpaperFileStore
    private let finder: FinderCacheDirectoryService
    private let setCurrentWallpaper: SetCurrentWallpaperUseCase
    private let managedRootURL: URL
    private let randomSelector: any RandomSelecting
    private var filterTask: Task<Void, Never>?

    init(
        repository: any WallpaperRepository,
        thumbnailProvider: any ThumbnailProviding,
        fileInventory: any ManagedFileInventoryProviding,
        fileStore: any WallpaperFileStore,
        finder: FinderCacheDirectoryService,
        setCurrentWallpaper: SetCurrentWallpaperUseCase,
        managedRootURL: URL,
        randomSelector: any RandomSelecting
    ) {
        self.repository = repository
        self.thumbnailProvider = thumbnailProvider
        self.fileInventory = fileInventory
        self.fileStore = fileStore
        self.finder = finder
        self.setCurrentWallpaper = setCurrentWallpaper
        self.managedRootURL = managedRootURL
        self.randomSelector = randomSelector
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            wallpapers = try await repository.allWallpapers().sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.id.rawValue.uuidString > $1.id.rawValue.uuidString
            }
            applyFilter()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func refresh() async {
        do {
            _ = try await MaintainWallpaperFilesUseCase(
                wallpapers: repository,
                fileInventory: fileInventory,
                logger: NoOpAppLogger()
            ).execute()
            await load()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setCurrent(_ wallpaper: Wallpaper) async {
        guard wallpaper.fileState == .available else {
            notice = OperationNotice(
                tone: .warning,
                message: UserMessageCatalog.message(
                    for: AppFailure(code: .fileOperationFailed)
                )
            )
            return
        }

        do {
            _ = try await setCurrentWallpaper.execute(
                wallpaperID: wallpaper.id,
                fileURL: fileURL(for: wallpaper)
            )
            await load()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func nextWallpaper() async {
        let currentID = wallpapers.first(where: \.isCurrent)?.id
        guard let next = await WallpaperSelectionPolicy.selectRandom(
            wallpapers,
            previousID: currentID,
            selector: randomSelector
        ) else {
            notice = OperationNotice(
                tone: .warning,
                message: UserMessageCatalog.message(
                    for: AppFailure(code: .noWallpaperCandidate)
                )
            )
            return
        }
        await setCurrent(next)
    }

    func delete(_ wallpaper: Wallpaper) async {
        guard !wallpaper.isCurrent else {
            notice = OperationNotice(
                tone: .warning,
                message: UserMessageCatalog.message(
                    for: AppFailure(code: .fileOperationFailed)
                )
            )
            return
        }

        do {
            try await fileStore.remove(relativePath: wallpaper.relativePath.rawValue)
            try await repository.delete(id: wallpaper.id)
            if selectedWallpaper?.id == wallpaper.id {
                selectedWallpaper = nil
            }
            await load()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func reveal(_ wallpaper: Wallpaper) async {
        do {
            _ = try await finder.reveal(relativePath: wallpaper.relativePath)
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setSearchText(_ value: String) {
        searchText = value
        filterTask?.cancel()
        filterTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.applyFilter()
        }
    }

    func fileURL(for wallpaper: Wallpaper) -> URL {
        managedRootURL.appendingPathComponent(wallpaper.relativePath.rawValue)
    }

    func thumbnailRequest(for wallpaper: Wallpaper, size: ThumbnailSize) -> ThumbnailRequest? {
        guard wallpaper.fileState == .available else { return nil }
        return ThumbnailRequest(
            sourceURL: fileURL(for: wallpaper),
            contentHash: wallpaper.contentHash,
            size: size
        )
    }

    func applyFilter() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            filteredWallpapers = wallpapers
            return
        }

        let lowercasedQuery = query.lowercased()
        let date = LocalDay(rawValue: query)
        filteredWallpapers = wallpapers.filter { wallpaper in
            if wallpaper.sourceNameSnapshot.lowercased().contains(lowercasedQuery) {
                return true
            }
            if let date, wallpaper.downloadDay == date {
                return true
            }
            return false
        }
    }

    private static func userMessage(for error: Error) -> UserMessage {
        if let failure = error as? AppFailure {
            return UserMessageCatalog.message(for: failure)
        }
        if let currentError = error as? CurrentWallpaperUpdateError {
            switch currentError {
            case .fileUnavailable, .invalidFileURL:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .fileOperationFailed)
                )
            case .noDisplaysAvailable, .allDisplaysFailed:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .wallpaperUpdateFailed)
                )
            case .wallpaperNotFound, .repository:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .unknown)
                )
            }
        }
        if let finderError = error as? FinderDirectoryError {
            switch finderError {
            case .invalidManagedPath, .directoryUnavailable:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .storageUnavailable)
                )
            case .fileMissing:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .fileOperationFailed)
                )
            case .openFailed:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .unknown)
                )
            }
        }
        return UserMessageCatalog.message(for: AppFailure(code: .unknown))
    }
}
