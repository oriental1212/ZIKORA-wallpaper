import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct RetryPolicyTests {
    @Test("Automatic retry schedule is deterministic")
    func schedule() {
        let now = Date(timeIntervalSince1970: 100)
        #expect(AutomaticRetryPolicy.decision(afterAutomaticAttemptCount: 1, at: now, usedDefaultSource: false) == .retryScheduled(at: Date(timeIntervalSince1970: 1_900)))
        #expect(AutomaticRetryPolicy.decision(afterAutomaticAttemptCount: 2, at: now, usedDefaultSource: false) == .retryScheduled(at: Date(timeIntervalSince1970: 7_300)))
        #expect(AutomaticRetryPolicy.decision(afterAutomaticAttemptCount: 3, at: now, usedDefaultSource: false) == .useDefaultSourceOnce)
        #expect(AutomaticRetryPolicy.decision(afterAutomaticAttemptCount: 3, at: now, usedDefaultSource: true) == .failedForDay)
    }

    @Test("Due retry recovery reads persistence without creating duplicate records")
    func dueRecovery() async throws {
        let day = LocalDay(rawValue: "2026-08-19")!
        let now = date(year: 2026, month: 8, day: 19, hour: 12)
        let record = DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: UUID()),
            taskKey: DailyFetchRecord.taskKey(for: day, taskKind: .automaticDaily),
            localDay: day,
            taskKind: .automaticDaily,
            plannedSourceID: nil,
            actualSourceID: nil,
            status: .retryScheduled,
            automaticAttemptCount: 1,
            usedDefaultSource: false,
            wallpaperID: nil,
            lastAttemptAt: now.addingTimeInterval(-3600),
            nextRetryAt: now.addingTimeInterval(-1),
            lastErrorCode: .networkUnavailable
        )
        let repository = try InMemoryRepositoryStore(records: [record])
        let coordinator = PersistentRetryCoordinator(
            records: repository,
            clock: FixedClock(date: now),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai"))
        )

        #expect(try await coordinator.dueRecords() == [record])
        #expect(try await repository.allRecords().count == 1)
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
