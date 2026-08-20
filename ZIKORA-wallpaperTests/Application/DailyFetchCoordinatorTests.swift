import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct DailyFetchCoordinatorTests {
    @Test("Slideshow mode never invokes the network workflow")
    func slideshowSkipsNetwork() async throws {
        let workflow = RecordingDailyWorkflow()
        var settings = UserSettings.defaults(id: UUID(), updatedAt: Date())
        settings.wallpaperMode = .slideshow
        let repository = try InMemoryRepositoryStore(settings: settings)
        let checker = DailyFetchChecker(
            settings: repository,
            records: repository,
            workflow: workflow
        )

        #expect(try await checker.checkToday(reason: .applicationStarted) == .skippedSlideshow)
        #expect(await workflow.callCount() == 0)
    }

    @Test("A successful record makes repeated system events idempotent")
    func successfulDayIsIdempotent() async throws {
        let day = LocalDay(rawValue: "2026-08-19")!
        let record = DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: UUID()),
            taskKey: DailyFetchRecord.taskKey(for: day, taskKind: .automaticDaily),
            localDay: day,
            taskKind: .automaticDaily,
            plannedSourceID: nil,
            actualSourceID: nil,
            status: .success,
            automaticAttemptCount: 1,
            usedDefaultSource: false,
            wallpaperID: nil,
            lastAttemptAt: Date(),
            nextRetryAt: nil,
            lastErrorCode: nil
        )
        let workflow = RecordingDailyWorkflow()
        let repository = try InMemoryRepositoryStore(records: [record])
        let checker = DailyFetchChecker(
            settings: repository,
            records: repository,
            workflow: workflow,
            clock: FixedClock(date: date(year: 2026, month: 8, day: 19, hour: 12)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai"))
        )

        let result = try await checker.checkToday(reason: .networkBecameAvailable)
        #expect(result == .alreadySucceeded(recordID: record.id))
        #expect(await workflow.callCount() == 0)
    }

    @Test("Concurrent platform events share one daily check")
    func eventStormCoalesces() async throws {
        let workflow = RecordingDailyWorkflow(delay: .milliseconds(20))
        let checker = StubDailyChecker(workflow: workflow)
        let coordinator = AutomaticFetchTriggerCoordinator(checker: checker)

        async let first = coordinator.handle(.applicationStarted)
        async let second = coordinator.handle(.wokeFromSleep)
        async let third = coordinator.handle(.networkBecameAvailable)
        _ = try await [first, second, third]

        #expect(await workflow.callCount() == 1)
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return value
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar(timeZoneID: "Asia/Shanghai").date(from: components)!
    }
}

private actor RecordingDailyWorkflow: WallpaperFetchWorkflow {
    private var calls = 0
    private let delay: Duration

    init(delay: Duration = .zero) { self.delay = delay }

    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        calls += 1
        if delay != .zero {
            await Task.yield()
            await Task.yield()
        }
        return FetchExecutionResult(taskKind: taskKind, wallpaperID: nil, usedDefaultSource: false)
    }

    func callCount() -> Int { calls }
}

private struct StubDailyChecker: DailyFetchChecking {
    let workflow: RecordingDailyWorkflow

    func checkToday(reason: FetchTriggerReason) async throws -> DailyFetchCheckOutcome {
        .started(try await workflow.execute(taskKind: .automaticDaily, reason: reason, progress: { _ in }))
    }
}
