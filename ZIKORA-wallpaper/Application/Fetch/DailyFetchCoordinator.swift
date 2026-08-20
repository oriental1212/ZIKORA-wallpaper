import Foundation

nonisolated struct DailyFetchChecker: DailyFetchChecking, Sendable {
    private let settings: any SettingsRepository
    private let records: any DailyFetchRepository
    private let workflow: any WallpaperFetchWorkflow
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding

    init(
        settings: any SettingsRepository,
        records: any DailyFetchRepository,
        workflow: any WallpaperFetchWorkflow,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider()
    ) {
        self.settings = settings
        self.records = records
        self.workflow = workflow
        self.clock = clock
        self.calendarProvider = calendarProvider
    }

    func checkToday(reason: FetchTriggerReason) async throws -> DailyFetchCheckOutcome {
        guard (try await settings.loadSettings()?.wallpaperMode ?? AppDefaults.wallpaperMode) == .daily else {
            return .skippedSlideshow
        }

        let day = LocalDay(
            containing: await clock.now(),
            calendar: await calendarProvider.calendar()
        )
        if let record = try await records.record(for: day, taskKind: .automaticDaily),
           record.status == .success {
            return .alreadySucceeded(recordID: record.id)
        }

        return .started(try await workflow.execute(
            taskKind: .automaticDaily,
            reason: reason,
            progress: { _ in }
        ))
    }
}

/// Translates platform events into one serialized daily check. It never polls time.
actor AutomaticFetchTriggerCoordinator {
    private let checker: any DailyFetchChecking
    private var activeCheck: Task<DailyFetchCheckOutcome, Error>?

    init(checker: any DailyFetchChecking) {
        self.checker = checker
    }

    func handle(_ event: SystemEvent) async throws -> DailyFetchCheckOutcome? {
        guard let reason = Self.reason(for: event) else { return nil }
        if let activeCheck {
            return try await activeCheck.value
        }

        let checker = self.checker
        let task = Task {
            try await checker.checkToday(reason: reason)
        }
        activeCheck = task
        do {
            let result = try await task.value
            activeCheck = nil
            return result
        } catch {
            activeCheck = nil
            throw error
        }
    }

    func consume(events: AsyncStream<SystemEvent>) async {
        for await event in events {
            _ = try? await handle(event)
        }
    }

    private static func reason(for event: SystemEvent) -> FetchTriggerReason? {
        switch event {
        case .applicationStarted: .applicationStarted
        case .wokeFromSleep: .wokeFromSleep
        case .localDayMayHaveChanged: .localDayMayHaveChanged
        case .timeZoneChanged: .timeZoneChanged
        case .networkBecameAvailable: .networkBecameAvailable
        }
    }
}
