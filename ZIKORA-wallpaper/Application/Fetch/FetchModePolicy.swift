import Foundation

nonisolated enum DailyFetchModeDecision: Sendable, Equatable {
    case start
    case alreadySucceeded
    case disabledBySlideshow
}

nonisolated enum ManualUpdateDecision: Sendable, Equatable {
    case startImmediately
    case reuseCurrent(wallpaperID: WallpaperID)
}

enum FetchModePolicy {
    static func automaticDecision(
        settings: UserSettings?,
        todayRecord: DailyFetchRecord?
    ) -> DailyFetchModeDecision {
        guard (settings?.wallpaperMode ?? AppDefaults.wallpaperMode) == .daily else {
            return .disabledBySlideshow
        }
        guard todayRecord?.status != .success else {
            return .alreadySucceeded
        }
        return .start
    }

    static func manualDecision(
        deduplication: WallpaperDeduplicationDecision
    ) -> ManualUpdateDecision {
        if deduplication.matchesCurrentWallpaper,
           let wallpaperID = deduplication.existingWallpaper?.id {
            return .reuseCurrent(wallpaperID: wallpaperID)
        }
        return .startImmediately
    }
}

nonisolated struct ManualWallpaperUpdateUseCase: Sendable {
    private let records: any DailyFetchRepository
    private let checker: any WallpaperFetchWorkflow
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating

    init(
        records: any DailyFetchRepository,
        checker: any WallpaperFetchWorkflow,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.records = records
        self.checker = checker
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.uuidGenerator = uuidGenerator
    }

    func execute() async throws -> FetchExecutionResult {
        _ = try await PrepareDailyFetchRecordUseCase(
            repository: records,
            clock: clock,
            calendarProvider: calendarProvider,
            uuidGenerator: uuidGenerator
        ).execute(taskKind: .manualUpdate, plannedSourceID: nil)
        return try await checker.execute(
            taskKind: .manualUpdate,
            reason: .manual,
            progress: { _ in }
        )
    }
}
