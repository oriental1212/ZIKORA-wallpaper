import Foundation

/// Owns the single low-frequency retry check. It never polls; it either waits
/// for the next persisted `nextRetryAt` or is rearmed by a platform event.
actor PersistentRetryScheduler: RetryScheduling {
    private let workflow: any WallpaperFetchWorkflow
    private let records: any DailyFetchRepository
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let sleeper: any AsyncSleeping
    private var checkTask: Task<Void, Never>?

    init(
        workflow: any WallpaperFetchWorkflow,
        records: any DailyFetchRepository,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider(),
        sleeper: any AsyncSleeping = SystemAsyncSleeper()
    ) {
        self.workflow = workflow
        self.records = records
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.sleeper = sleeper
    }

    func scheduleCheck(at date: Date) async {
        let now = await clock.now()
        if date <= now {
            await runDue()
            return
        }

        checkTask?.cancel()
        let delay = date.timeIntervalSince(now)
        checkTask = Task { [weak self] in
            do {
                try await self?.sleeper.sleep(for: .seconds(max(0, delay)))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.runDue()
        }
    }

    func cancelScheduledCheck() async {
        checkTask?.cancel()
        checkTask = nil
    }

    func scheduleNextDue() async {
        guard let all = try? await records.allRecords() else {
            return
        }
        let now = await clock.now()
        let calendar = await calendarProvider.calendar()
        let today = LocalDay(containing: now, calendar: calendar)
        let due = all.filter { $0.isAutomaticRetryDue(at: now, on: today) }
        if !due.isEmpty {
            await runDue()
            return
        }

        let nextDate = all
            .compactMap(\.nextRetryAt)
            .filter { $0 > now }
            .min()
        if let nextDate {
            await scheduleCheck(at: nextDate)
        }
    }

    private func runDue() async {
        guard let all = try? await records.allRecords() else {
            return
        }
        let now = await clock.now()
        let calendar = await calendarProvider.calendar()
        let today = LocalDay(containing: now, calendar: calendar)
        let due = all.filter { $0.isAutomaticRetryDue(at: now, on: today) }
        guard !due.isEmpty else {
            return
        }

        for _ in due {
            _ = try? await workflow.execute(
                taskKind: .automaticDaily,
                reason: .retryDue,
                progress: { _ in }
            )
        }

        let remaining = (try? await records.allRecords()) ?? []
        let nextDate = remaining
            .compactMap(\.nextRetryAt)
            .filter { $0 > now }
            .min()
        if let nextDate {
            await scheduleCheck(at: nextDate)
        }
    }
}
