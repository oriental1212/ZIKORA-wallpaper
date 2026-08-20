import Foundation

nonisolated struct ContentHash: Sendable, Equatable, Hashable {
    let value: String
    let byteCount: Int64
}

nonisolated protocol ImageContentHashing: Sendable {
    func hash(fileAt url: URL) async throws -> ContentHash
}

nonisolated struct DownloadedImage: Sendable, Equatable {
    let temporaryFileURL: URL
    let responseMIMEType: String?
    let byteCount: Int64
}

nonisolated protocol ImageDownloading: Sendable {
    func download(from url: URL) async throws -> DownloadedImage
}

nonisolated struct ValidatedImage: Sendable, Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let formatIdentifier: String
}

nonisolated protocol ImageValidating: Sendable {
    func validate(fileAt url: URL, declaredMIMEType: String?) async throws -> ValidatedImage
}

nonisolated struct ThumbnailSize: Hashable, Sendable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    var maxPixelSize: Int {
        max(width, height)
    }
}

nonisolated struct ThumbnailRequest: Hashable, Sendable {
    let sourceURL: URL
    let contentHash: String
    let size: ThumbnailSize
}

nonisolated protocol ThumbnailRendering: Sendable {
    func render(sourceURL: URL, destinationURL: URL, maxPixelSize: Int) async throws
}

nonisolated protocol ThumbnailProviding: Sendable {
    func thumbnail(for request: ThumbnailRequest) async throws -> URL
    func invalidate(contentHash: String) async
}

nonisolated struct FileStoreStatistics: Sendable, Equatable {
    let fileCount: Int
    let byteCount: Int64
}

nonisolated protocol WallpaperFileStore: Sendable {
    func commitTemporaryFile(at url: URL, preferredExtension: String) async throws -> String
    func remove(relativePath: String) async throws
    func statistics() async throws -> FileStoreStatistics
}

nonisolated struct ManagedCacheLocation: Sendable, Equatable {
    let directoryURL: URL
    let displayPath: String
}

nonisolated protocol ManagedCacheInspecting: Sendable {
    func statistics() async throws -> FileStoreStatistics
    func invalidateStatistics() async
    func location() async throws -> ManagedCacheLocation
}

nonisolated protocol ManagedFileInventoryProviding: Sendable {
    func inventory() async throws -> Set<ManagedRelativePath>
}

nonisolated struct DisplayID: Hashable, Sendable {
    let rawValue: String
}

nonisolated struct DisplayWallpaperResult: Sendable, Equatable {
    let displayID: DisplayID
    let succeeded: Bool
}

nonisolated protocol DesktopWallpaperSetting: Sendable {
    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult]
}

nonisolated enum SystemEvent: Sendable, Equatable {
    case applicationStarted
    case wokeFromSleep
    case localDayMayHaveChanged
    case timeZoneChanged
    case networkBecameAvailable
}

nonisolated protocol SystemEventProviding: Sendable {
    func events() -> AsyncStream<SystemEvent>
}

nonisolated protocol RetryScheduling: Sendable {
    func scheduleCheck(at date: Date) async
    func cancelScheduledCheck() async
}

nonisolated enum FetchTriggerReason: String, Sendable, Equatable {
    case manual
    case applicationStarted
    case wokeFromSleep
    case localDayMayHaveChanged
    case timeZoneChanged
    case networkBecameAvailable
    case retryDue
}

nonisolated enum FetchProgressPhase: String, Sendable, Equatable {
    case checking
    case resolvingSource
    case downloading
    case validating
    case hashing
    case committing
    case applying
    case recordingSuccess
    case cleaning
}

nonisolated struct FetchProgress: Sendable, Equatable {
    let phase: FetchProgressPhase
    let fraction: Double?
}

nonisolated struct FetchExecutionResult: Sendable, Equatable {
    let taskKind: FetchTaskKind
    let wallpaperID: WallpaperID?
    let usedDefaultSource: Bool
}

nonisolated protocol WallpaperFetchWorkflow: Sendable {
    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult
}

nonisolated protocol FetchOrchestrating: Sendable {
    func run(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason
    ) async throws -> FetchExecutionResult
    func isRunning() async -> Bool
}

nonisolated enum DailyFetchCheckOutcome: Sendable, Equatable {
    case skippedSlideshow
    case alreadySucceeded(recordID: DailyFetchRecordID)
    case started(FetchExecutionResult)
}

nonisolated protocol DailyFetchChecking: Sendable {
    func checkToday(reason: FetchTriggerReason) async throws -> DailyFetchCheckOutcome
}

nonisolated enum RetryDecision: Sendable, Equatable {
    case retryScheduled(at: Date)
    case useDefaultSourceOnce
    case failedForDay
}

nonisolated protocol RetryCoordinating: Sendable {
    func recordFailure(
        for record: DailyFetchRecord,
        at date: Date,
        usedDefaultSource: Bool
    ) async throws -> DailyFetchRecord
    func dueRecords() async throws -> [DailyFetchRecord]
}

nonisolated protocol AsyncSleeping: Sendable {
    func sleep(for duration: Duration) async throws
}

nonisolated struct SystemAsyncSleeper: AsyncSleeping {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

nonisolated protocol RotationCandidateProviding: Sendable {
    func candidates() async throws -> [Wallpaper]
}

nonisolated protocol RotationWallpaperApplying: Sendable {
    func apply(wallpaper: Wallpaper) async throws
}

nonisolated enum MenuBarCommand: Sendable, Equatable {
    case updateNow
    case nextWallpaper
    case openMainWindow
    case openSettings
    case retry
    case quit
}

nonisolated protocol MenuBarCommandHandling: Sendable {
    func handle(_ command: MenuBarCommand) async
}

nonisolated enum MenuBarPresentationState: Sendable, Equatable {
    case noCurrentWallpaper
    case idle(currentWallpaperID: WallpaperID)
    case running
    case failed(message: String, canRetry: Bool)
}

nonisolated enum LoginItemStatus: Sendable, Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

nonisolated protocol LoginItemManaging: Sendable {
    func status() async -> LoginItemStatus
    func setEnabled(_ enabled: Bool) async throws
}
