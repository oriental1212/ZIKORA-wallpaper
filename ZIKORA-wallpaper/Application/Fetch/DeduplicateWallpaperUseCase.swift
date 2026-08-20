import Foundation

nonisolated struct WallpaperDeduplicationDecision: Sendable, Equatable {
    let contentHash: ContentHash
    let existingWallpaper: Wallpaper?

    var reusesExistingWallpaper: Bool {
        existingWallpaper != nil
    }

    var matchesCurrentWallpaper: Bool {
        existingWallpaper?.isCurrent == true
    }
}

/// Resolves content identity before a temporary file is committed to managed storage.
nonisolated struct DeduplicateWallpaperUseCase: Sendable {
    private let wallpapers: any WallpaperRepository
    private let hasher: any ImageContentHashing

    init(
        wallpapers: any WallpaperRepository,
        hasher: any ImageContentHashing = SHA256ImageHasher()
    ) {
        self.wallpapers = wallpapers
        self.hasher = hasher
    }

    func execute(fileAt url: URL) async throws -> WallpaperDeduplicationDecision {
        let contentHash = try await hasher.hash(fileAt: url)
        let existingWallpaper = try await wallpapers.wallpaper(contentHash: contentHash.value)
        return WallpaperDeduplicationDecision(
            contentHash: contentHash,
            existingWallpaper: existingWallpaper
        )
    }
}

/// Associates a resolved wallpaper with the fetch event without creating a second physical record.
nonisolated struct AssociateWallpaperWithFetchUseCase: Sendable {
    private let records: any DailyFetchRepository

    init(records: any DailyFetchRepository) {
        self.records = records
    }

    func execute(
        record: DailyFetchRecord,
        wallpaper: Wallpaper,
        actualSourceID: SourceID?,
        attemptedAt: Date
    ) async throws -> DailyFetchRecord {
        var completed = record
        completed.actualSourceID = actualSourceID
        completed.status = .success
        completed.wallpaperID = wallpaper.id
        completed.lastAttemptAt = attemptedAt
        completed.nextRetryAt = nil
        completed.lastErrorCode = nil
        try await records.save(completed)
        return completed
    }
}
