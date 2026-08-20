import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct FetchModePolicyTests {
    @Test("Automatic daily mode is gated by today's success, while manual is separate")
    func dailyAndManualPolicies() {
        var settings = UserSettings.defaults(id: UUID(), updatedAt: Date())
        let day = LocalDay(rawValue: "2026-08-19")!
        let record = DailyFetchRecord.pending(
            id: DailyFetchRecordID(rawValue: UUID()),
            day: day,
            taskKind: .automaticDaily,
            plannedSourceID: nil
        )

        #expect(FetchModePolicy.automaticDecision(settings: settings, todayRecord: record) == .start)
        var completed = record
        completed.status = .success
        #expect(FetchModePolicy.automaticDecision(settings: settings, todayRecord: completed) == .alreadySucceeded)
        settings.wallpaperMode = .slideshow
        #expect(FetchModePolicy.automaticDecision(settings: settings, todayRecord: record) == .disabledBySlideshow)
    }

    @Test("A manual prepare creates a distinct task and does not change automatic attempts")
    func manualTaskIsIndependent() async throws {
        let repository = try InMemoryRepositoryStore()
        let checker = RecordingModeWorkflow()
        let useCase = ManualWallpaperUpdateUseCase(
            records: repository,
            checker: checker,
            clock: FixedClock(date: date(year: 2026, month: 8, day: 19)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai")),
            uuidGenerator: FixedUUIDGenerator(value: UUID())
        )
        _ = try await useCase.execute()
        let records = try await repository.allRecords()
        #expect(records.count == 1)
        #expect(records[0].taskKind == .manualUpdate)
        #expect(records[0].automaticAttemptCount == 0)
        #expect(await checker.lastTaskKind() == .manualUpdate)
    }

    @Test("A duplicate current wallpaper produces a reuse notice")
    func currentHashReuse() {
        let wallpaper = Wallpaper(
            id: WallpaperID(rawValue: UUID()), contentHash: "same", sourceID: nil,
            sourceNameSnapshot: "source", relativePath: ManagedRelativePath(rawValue: "2026-08-19/a.jpg")!,
            downloadDay: LocalDay(rawValue: "2026-08-19")!, createdAt: Date(), pixelWidth: 1,
            pixelHeight: 1, fileSize: 1, format: .jpeg, fileState: .available, isCurrent: true
        )
        let decision = FetchModePolicy.manualDecision(deduplication: WallpaperDeduplicationDecision(
            contentHash: ContentHash(value: "same", byteCount: 1), existingWallpaper: wallpaper
        ))
        #expect(decision == .reuseCurrent(wallpaperID: wallpaper.id))
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return value
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = 12
        return calendar(timeZoneID: "Asia/Shanghai").date(from: components)!
    }
}

private actor RecordingModeWorkflow: WallpaperFetchWorkflow {
    private var taskKind: FetchTaskKind?

    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        self.taskKind = taskKind
        return FetchExecutionResult(taskKind: taskKind, wallpaperID: nil, usedDefaultSource: false)
    }

    func lastTaskKind() -> FetchTaskKind? { taskKind }
}
