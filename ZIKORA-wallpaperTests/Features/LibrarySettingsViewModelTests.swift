import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct LibraryViewModelTests {
    @Test("Library loads newest first and excludes missing files from thumbnail requests")
    func loadAndSort() async throws {
        let store = try InMemoryRepositoryStore()
        let older = try makeWallpaper(id: 1, createdAt: 100, isCurrent: false)
        let newer = try makeWallpaper(id: 2, createdAt: 200, isCurrent: false, fileState: .missing)
        try await store.save(older)
        try await store.save(newer)

        let model = makeModel(store: store)
        await model.load()

        #expect(model.wallpapers.map(\.id) == [newer.id, older.id])
        #expect(model.filteredWallpapers.map(\.id) == [newer.id, older.id])
        #expect(model.thumbnailRequest(for: older, size: ThumbnailSize(width: 10, height: 10)) != nil)
        #expect(model.thumbnailRequest(for: newer, size: ThumbnailSize(width: 10, height: 10)) == nil)
    }

    @Test("Refresh runs local maintenance without network and restores a missing file")
    func refreshIsLocalOnly() async throws {
        let store = try InMemoryRepositoryStore()
        let wallpaper = try makeWallpaper(id: 1, createdAt: 100, fileState: .missing)
        try await store.save(wallpaper)
        let inventory = StubFileInventory(paths: [wallpaper.relativePath])
        let model = makeModel(store: store, inventory: inventory)

        await model.refresh()

        #expect(try await store.wallpaper(id: wallpaper.id)?.fileState == .available)
    }

    @Test("Setting current updates the unique current marker")
    func setCurrent() async throws {
        let store = try InMemoryRepositoryStore()
        let first = try makeWallpaper(id: 1, createdAt: 100)
        let second = try makeWallpaper(id: 2, createdAt: 200)
        try await store.save(first)
        try await store.save(second)
        let model = makeModel(store: store)
        await model.load()

        await model.setCurrent(first)

        #expect(try await store.wallpaper(id: first.id)?.isCurrent == true)
        #expect(try await store.wallpaper(id: second.id)?.isCurrent == false)
    }

    @Test("Search filters by source name snapshot and local date")
    func searchFilter() async throws {
        let store = try InMemoryRepositoryStore()
        let first = try makeWallpaper(id: 1, createdAt: 100, sourceName: "NASA")
        let second = try makeWallpaper(id: 2, createdAt: 200, sourceName: "Bing")
        try await store.save(first)
        try await store.save(second)
        let model = makeModel(store: store)
        await model.load()

        model.searchText = "nasa"
        model.applyFilter()
        #expect(model.filteredWallpapers.map(\.id) == [first.id])

        model.searchText = "2026-08-20"
        model.applyFilter()
        #expect(model.filteredWallpapers.count == 2)
    }

    private func makeModel(
        store: any RepositoryStore,
        inventory: any ManagedFileInventoryProviding = StubFileInventory(paths: [])
    ) -> LibraryViewModel {
        LibraryViewModel(
            repository: store,
            thumbnailProvider: StubThumbnailProvider(),
            fileInventory: inventory,
            fileStore: StubWallpaperFileStore(),
            finder: FinderCacheDirectoryService(
                rootURL: FileManager.default.temporaryDirectory,
                opener: StubURLOpener()
            ),
            setCurrentWallpaper: SetCurrentWallpaperUseCase(
                wallpapers: store,
                desktopWallpaperSetter: StubDesktopWallpaperSetter()
            ),
            managedRootURL: FileManager.default.temporaryDirectory,
            randomSelector: FixedRandomSelector(value: 0)
        )
    }
}

@MainActor
struct SettingsViewModelTests {
    @Test("Settings load persists defaults and synchronizes login item state")
    func loadDefaults() async throws {
        let store = try InMemoryRepositoryStore()
        let model = makeModel(store: store)

        await model.load()

        #expect(model.settings?.wallpaperMode == .daily)
        #expect(model.settings?.retentionPolicy == .thirtyDays)
        #expect(model.loginItemStatus == .enabled)
    }

    @Test("Wallpaper mode and retention policy persist immediately")
    func persistSettings() async throws {
        let store = try InMemoryRepositoryStore()
        let model = makeModel(store: store)
        await model.load()

        await model.setWallpaperMode(.slideshow)
        await model.setRetentionPolicy(.ninetyDays)

        #expect(model.settings?.wallpaperMode == .slideshow)
        #expect(model.settings?.retentionPolicy == .ninetyDays)
        #expect(try await store.loadSettings()?.wallpaperMode == .slideshow)
        #expect(try await store.loadSettings()?.retentionPolicy == .ninetyDays)
    }

    @Test("Cleanup estimate protects current wallpaper and reports deleted items")
    func cleanupEstimate() async throws {
        let store = try InMemoryRepositoryStore()
        let current = try makeWallpaper(id: 1, createdAt: 1, isCurrent: true)
        let old = try makeWallpaper(id: 2, createdAt: 2, isCurrent: false)
        try await store.save(current)
        try await store.save(old)
        let model = makeModel(store: store, fileStore: StubWallpaperFileStore())
        await model.load()

        await model.setRetentionPolicy(.sevenDays)

        #expect(model.cleanupEstimate != nil)
        #expect(model.cleanupEstimate?.candidates.contains {
            $0.wallpaperID == current.id
        } == false)
    }

    private func makeModel(
        store: any RepositoryStore,
        fileStore: any WallpaperFileStore = StubWallpaperFileStore()
    ) -> SettingsViewModel {
        let inventory = StubFileInventory(paths: [])
        let scheduler = RotationScheduler(
            settings: store,
            candidates: StubRotationCandidates(wallpapers: []),
            applier: StubRotationApplier(),
            selector: FixedRandomSelector(value: 0),
            sleeper: StubAsyncSleeper()
        )
        return SettingsViewModel(
            repository: store,
            loginItemCoordinator: LoginItemToggleCoordinator(
                manager: StubLoginItemManager(status: .enabled)
            ),
            rotationScheduler: scheduler,
            fileStore: fileStore,
            fileInventory: inventory,
            cacheInspector: StubCacheInspector(),
            finder: FinderCacheDirectoryService(
                rootURL: FileManager.default.temporaryDirectory,
                opener: StubURLOpener()
            ),
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_787_000_000)),
            calendar: FixedCalendarProvider(value: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
                return calendar
            }()),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(90))
        )
    }
}

private func makeWallpaper(
    id: UInt8,
    createdAt: TimeInterval,
    isCurrent: Bool = false,
    fileState: WallpaperFileState = .available,
    sourceName: String = "Source"
) throws -> Wallpaper {
    Wallpaper(
        id: WallpaperID(rawValue: fixedUUID(id)),
        contentHash: "hash-\(id)",
        sourceID: nil,
        sourceNameSnapshot: sourceName,
        relativePath: try #require(ManagedRelativePath(rawValue: "2026/08/\(id).jpg")),
        downloadDay: try #require(LocalDay(rawValue: "2026-08-20")),
        createdAt: Date(timeIntervalSince1970: createdAt),
        pixelWidth: 1920,
        pixelHeight: 1080,
        fileSize: 1234,
        format: .jpeg,
        fileState: fileState,
        isCurrent: isCurrent
    )
}

private struct StubThumbnailProvider: ThumbnailProviding {
    func thumbnail(for request: ThumbnailRequest) async throws -> URL {
        request.sourceURL
    }

    func invalidate(contentHash: String) async {
    }
}

private struct StubFileInventory: ManagedFileInventoryProviding {
    let paths: Set<ManagedRelativePath>

    init(paths: Set<ManagedRelativePath>) {
        self.paths = paths
    }

    func inventory() async throws -> Set<ManagedRelativePath> {
        paths
    }
}

private struct StubWallpaperFileStore: WallpaperFileStore {
    func commitTemporaryFile(at url: URL, preferredExtension: String) async throws -> String {
        "temporary"
    }

    func remove(relativePath: String) async throws {
    }

    func statistics() async throws -> FileStoreStatistics {
        FileStoreStatistics(fileCount: 0, byteCount: 0)
    }
}

private struct StubURLOpener: URLOpening {
    func open(_ url: URL) async -> Bool {
        true
    }
}

private struct StubDesktopWallpaperSetter: DesktopWallpaperSetting {
    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult] {
        [DisplayWallpaperResult(displayID: DisplayID(rawValue: "test"), succeeded: true)]
    }
}

private struct StubLoginItemManager: LoginItemManaging {
    let status: LoginItemStatus

    init(status: LoginItemStatus) {
        self.status = status
    }

    func status() async -> LoginItemStatus {
        status
    }

    func setEnabled(_ enabled: Bool) async throws {
    }
}

private struct StubCacheInspector: ManagedCacheInspecting {
    func statistics() async throws -> FileStoreStatistics {
        FileStoreStatistics(fileCount: 1, byteCount: 10)
    }

    func invalidateStatistics() async {
    }

    func location() async throws -> ManagedCacheLocation {
        ManagedCacheLocation(
            directoryURL: FileManager.default.temporaryDirectory,
            displayPath: "/tmp"
        )
    }
}

private struct StubRotationCandidates: RotationCandidateProviding, Sendable {
    let wallpapers: [Wallpaper]

    func candidates() async throws -> [Wallpaper] {
        wallpapers
    }
}

private struct StubRotationApplier: RotationWallpaperApplying, Sendable {
    func apply(wallpaper: Wallpaper) async throws {
    }
}

private struct StubAsyncSleeper: AsyncSleeping, Sendable {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

private func fixedUUID(_ value: UInt8) -> UUID {
    UUID(uuid: (
        UInt8(value), 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0
    ))
}
