import Foundation

/// Low-frequency cache inspection boundary used by Library and Settings.
actor ManagedCacheService: ManagedCacheInspecting {
    private let rootURL: URL
    private let fileStore: any WallpaperFileStore
    private let clock: any Clock
    private let refreshInterval: TimeInterval
    private let fileManager: FileManager
    private var cachedStatistics: FileStoreStatistics?
    private var lastRefreshAt: Date?

    init(
        rootURL: URL,
        fileStore: any WallpaperFileStore,
        clock: any Clock = SystemClock(),
        refreshInterval: TimeInterval = 2,
        fileManager: FileManager = .default
    ) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.fileStore = fileStore
        self.clock = clock
        self.refreshInterval = max(0, refreshInterval)
        self.fileManager = fileManager

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: self.rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AppFailure(code: .storageUnavailable)
        }
    }

    func statistics() async throws -> FileStoreStatistics {
        let now = await clock.now()
        if let cachedStatistics,
           let lastRefreshAt,
           now.timeIntervalSince(lastRefreshAt) < refreshInterval {
            return cachedStatistics
        }

        let statistics = try await fileStore.statistics()
        cachedStatistics = statistics
        lastRefreshAt = now
        return statistics
    }

    func invalidateStatistics() async {
        cachedStatistics = nil
        lastRefreshAt = nil
    }

    func location() async throws -> ManagedCacheLocation {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              rootURL.isFileURL else {
            throw AppFailure(code: .storageUnavailable)
        }
        return ManagedCacheLocation(
            directoryURL: rootURL,
            displayPath: Self.displayPath(for: rootURL, fileManager: fileManager)
        )
    }

    private nonisolated static func displayPath(
        for url: URL,
        fileManager: FileManager
    ) -> String {
        let path = url.standardizedFileURL.path
        let homePath = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path == homePath {
            return "Home"
        }
        if path.hasPrefix(homePath + "/") {
            return "Home" + String(path.dropFirst(homePath.count))
        }
        return path
    }
}
