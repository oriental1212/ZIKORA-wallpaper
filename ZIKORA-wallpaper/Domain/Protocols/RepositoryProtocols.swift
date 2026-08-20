import Foundation

nonisolated protocol SourceRepository: Sendable {
    func allSources() async throws -> [WallpaperSource]
    func source(id: SourceID) async throws -> WallpaperSource?
    func save(_ source: WallpaperSource) async throws
    func delete(id: SourceID, scheduleUpdatedAt: Date) async throws -> SourceDeletionImpact
}

nonisolated protocol ScheduleRepository: Sendable {
    func loadSchedule() async throws -> WeeklySchedule?
    func save(_ schedule: WeeklySchedule) async throws
}

nonisolated protocol WallpaperRepository: Sendable {
    func allWallpapers() async throws -> [Wallpaper]
    func wallpaper(id: WallpaperID) async throws -> Wallpaper?
    func wallpaper(contentHash: String) async throws -> Wallpaper?
    func save(_ wallpaper: Wallpaper) async throws
    func delete(id: WallpaperID) async throws
    func markFileState(id: WallpaperID, state: WallpaperFileState) async throws
    func markCurrent(id: WallpaperID) async throws
}

nonisolated protocol DailyFetchRepository: Sendable {
    func allRecords() async throws -> [DailyFetchRecord]
    func record(for day: LocalDay, taskKind: FetchTaskKind) async throws -> DailyFetchRecord?
    func prepareRecord(
        for day: LocalDay,
        taskKind: FetchTaskKind,
        id: DailyFetchRecordID,
        plannedSourceID: SourceID?
    ) async throws -> DailyFetchRecord
    func save(_ record: DailyFetchRecord) async throws
}

nonisolated protocol SettingsRepository: Sendable {
    func loadSettings() async throws -> UserSettings?
    func save(_ settings: UserSettings) async throws
}

typealias RepositoryStore = SourceRepository
    & ScheduleRepository
    & WallpaperRepository
    & DailyFetchRepository
    & SettingsRepository
