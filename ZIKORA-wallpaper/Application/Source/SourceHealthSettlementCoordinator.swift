import Foundation

/// Owns the natural-day settlement boundary; request failures alone never increment days.
actor SourceHealthSettlementCoordinator {
    private let health: UpdateSourceHealthUseCase
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private var settledDays: Set<SettlementKey> = []

    init(
        health: UpdateSourceHealthUseCase,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider()
    ) {
        self.health = health
        self.clock = clock
        self.calendarProvider = calendarProvider
    }

    func markRequestStarted(sourceID: SourceID) async throws -> WallpaperSource {
        try await health.execute(
            sourceID: sourceID,
            event: .requestStarted(at: await clock.now())
        )
    }

    func markRequestFailed(
        sourceID: SourceID,
        status: SourceFetchStatus,
        errorCode: AppErrorCode,
        message: String?
    ) async throws -> WallpaperSource {
        try await health.execute(
            sourceID: sourceID,
            event: .requestFailed(
                at: await clock.now(),
                status: status,
                errorCode: errorCode,
                redactedMessage: message
            )
        )
    }

    func settleFailure(
        sourceID: SourceID,
        status: SourceFetchStatus,
        errorCode: AppErrorCode,
        message: String?
    ) async throws -> WallpaperSource? {
        let day = LocalDay(
            containing: await clock.now(),
            calendar: await calendarProvider.calendar()
        )
        let key = SettlementKey(sourceID: sourceID, day: day)
        guard settledDays.insert(key).inserted else { return nil }
        return try await health.execute(
            sourceID: sourceID,
            event: .dailyFailureSettled(
                at: await clock.now(),
                status: status,
                errorCode: errorCode,
                redactedMessage: message
            )
        )
    }

    func markSuccess(sourceID: SourceID) async throws -> WallpaperSource {
        try await health.execute(
            sourceID: sourceID,
            event: .requestSucceeded(at: await clock.now())
        )
    }
}

private nonisolated struct SettlementKey: Hashable, Sendable {
    let sourceID: SourceID
    let day: LocalDay
}
