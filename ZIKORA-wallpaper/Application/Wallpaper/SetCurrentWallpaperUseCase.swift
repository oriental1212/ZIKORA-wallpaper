import Foundation

nonisolated enum CurrentWallpaperUpdateOutcome: Equatable, Sendable {
    case unchanged(wallpaperID: WallpaperID)
    case applied(wallpaperID: WallpaperID, succeededDisplayCount: Int)
    case appliedWithWarning(
        wallpaperID: WallpaperID,
        succeededDisplayCount: Int,
        failedDisplayCount: Int
    )
}

nonisolated enum CurrentWallpaperUpdateError: Error, Equatable, Sendable {
    case wallpaperNotFound
    case fileUnavailable
    case invalidFileURL
    case noDisplaysAvailable
    case allDisplaysFailed(failedDisplayCount: Int)
    case repository(RepositoryError)
}

nonisolated struct SetCurrentWallpaperUseCase: Sendable {
    private let wallpapers: any WallpaperRepository
    private let desktopWallpaperSetter: any DesktopWallpaperSetting

    init(
        wallpapers: any WallpaperRepository,
        desktopWallpaperSetter: any DesktopWallpaperSetting
    ) {
        self.wallpapers = wallpapers
        self.desktopWallpaperSetter = desktopWallpaperSetter
    }

    func execute(
        wallpaperID: WallpaperID,
        fileURL: URL
    ) async throws -> CurrentWallpaperUpdateOutcome {
        try Task.checkCancellation()

        let target: Wallpaper
        do {
            guard let storedWallpaper = try await wallpapers.wallpaper(id: wallpaperID) else {
                throw CurrentWallpaperUpdateError.wallpaperNotFound
            }
            target = storedWallpaper
        } catch let error as CurrentWallpaperUpdateError {
            throw error
        } catch let error as RepositoryError {
            throw CurrentWallpaperUpdateError.repository(error)
        }

        guard target.fileState == .available else {
            throw CurrentWallpaperUpdateError.fileUnavailable
        }
        guard fileURL.isFileURL else {
            throw CurrentWallpaperUpdateError.invalidFileURL
        }

        if target.isCurrent {
            try await commitCurrent(wallpaperID)
            return .unchanged(wallpaperID: wallpaperID)
        }

        try Task.checkCancellation()
        let displayResults = await desktopWallpaperSetter.setWallpaper(fileURL: fileURL)
        try Task.checkCancellation()

        guard !displayResults.isEmpty else {
            throw CurrentWallpaperUpdateError.noDisplaysAvailable
        }

        let succeededCount = displayResults.lazy.filter(\.succeeded).count
        let failedCount = displayResults.count - succeededCount
        guard succeededCount > 0 else {
            throw CurrentWallpaperUpdateError.allDisplaysFailed(
                failedDisplayCount: failedCount
            )
        }

        try await commitCurrent(wallpaperID)

        if failedCount > 0 {
            return .appliedWithWarning(
                wallpaperID: wallpaperID,
                succeededDisplayCount: succeededCount,
                failedDisplayCount: failedCount
            )
        }
        return .applied(
            wallpaperID: wallpaperID,
            succeededDisplayCount: succeededCount
        )
    }

    private func commitCurrent(_ wallpaperID: WallpaperID) async throws {
        do {
            try await wallpapers.markCurrent(id: wallpaperID)
        } catch let error as RepositoryError {
            throw CurrentWallpaperUpdateError.repository(error)
        }
    }
}
