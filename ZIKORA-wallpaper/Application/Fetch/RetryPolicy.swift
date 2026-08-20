import Foundation

nonisolated enum AutomaticRetryPolicy {
    static func decision(
        afterAutomaticAttemptCount count: Int,
        at date: Date,
        usedDefaultSource: Bool
    ) -> RetryDecision {
        switch count {
        case 1:
            .retryScheduled(at: date.addingTimeInterval(30 * 60))
        case 2:
            .retryScheduled(at: date.addingTimeInterval(2 * 60 * 60))
        case 3 where !usedDefaultSource:
            .useDefaultSourceOnce
        default:
            .failedForDay
        }
    }
}

actor PersistentRetryCoordinator: RetryCoordinating {
    private let records: any DailyFetchRepository
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding

    init(
        records: any DailyFetchRepository,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider()
    ) {
        self.records = records
        self.clock = clock
        self.calendarProvider = calendarProvider
    }

    func recordFailure(
        for record: DailyFetchRecord,
        at date: Date,
        usedDefaultSource: Bool
    ) async throws -> DailyFetchRecord {
        var updated = record
        if record.taskKind == .automaticDaily {
            updated.automaticAttemptCount += 1
        }
        let decision = AutomaticRetryPolicy.decision(
            afterAutomaticAttemptCount: updated.automaticAttemptCount,
            at: date,
            usedDefaultSource: usedDefaultSource
        )
        updated.status = .failed
        updated.nextRetryAt = nil
        switch decision {
        case .retryScheduled(let retryAt):
            updated.status = .retryScheduled
            updated.nextRetryAt = retryAt
        case .useDefaultSourceOnce:
            updated.usedDefaultSource = true
        case .failedForDay:
            break
        }
        updated.lastAttemptAt = date
        try await records.save(updated)
        return updated
    }

    func dueRecords() async throws -> [DailyFetchRecord] {
        let now = await clock.now()
        let calendar = await calendarProvider.calendar()
        let today = LocalDay(containing: now, calendar: calendar)
        return try await records.allRecords().filter {
            $0.isAutomaticRetryDue(at: now, on: today)
        }
    }
}
