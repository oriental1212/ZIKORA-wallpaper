import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct PrepareDailyFetchRecordUseCaseTests {
    enum Backend: String, CaseIterable, Sendable {
        case inMemory
        case swiftData
    }

    @Test("Concurrent triggers create one canonical daily task", arguments: Backend.allCases)
    func concurrentTriggersAreIdempotent(backend: Backend) async throws {
        let store = try makeStore(backend)
        let instant = Date(timeIntervalSince1970: 1_787_097_600)
        let sourceID = SourceID(rawValue: fixedUUID(1))
        let useCase = PrepareDailyFetchRecordUseCase(
            repository: store,
            clock: FixedClock(date: instant),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai"))
        )

        let ids = try await withThrowingTaskGroup(of: DailyFetchRecordID.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    (try await useCase.execute(
                        taskKind: .automaticDaily,
                        plannedSourceID: sourceID
                    )).id
                }
            }

            var values: [DailyFetchRecordID] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }

        let day = LocalDay(containing: instant, calendar: calendar(timeZoneID: "Asia/Shanghai"))
        #expect(Set(ids).count == 1)
        #expect(try await store.allRecords().count == 1)
        #expect(try await store.record(for: day, taskKind: .automaticDaily)?.taskKey
            == DailyFetchRecord.taskKey(for: day, taskKind: .automaticDaily))
    }

    @Test("Changing time zone archives a retry from the previous local day", arguments: Backend.allCases)
    func timeZoneChangeArchivesStaleRetry(backend: Backend) async throws {
        let store = try makeStore(backend)
        let instant = Date(timeIntervalSince1970: 1_787_097_600)
        let shanghaiDay = LocalDay(
            containing: instant,
            calendar: calendar(timeZoneID: "Asia/Shanghai")
        )
        let losAngelesDay = LocalDay(
            containing: instant,
            calendar: calendar(timeZoneID: "America/Los_Angeles")
        )
        #expect(shanghaiDay != losAngelesDay)

        var oldRecord = try await store.prepareRecord(
            for: shanghaiDay,
            taskKind: .automaticDaily,
            id: DailyFetchRecordID(rawValue: fixedUUID(2)),
            plannedSourceID: nil
        )
        oldRecord.status = .retryScheduled
        oldRecord.automaticAttemptCount = 2
        oldRecord.nextRetryAt = instant.addingTimeInterval(120)
        try await store.save(oldRecord)

        let useCase = PrepareDailyFetchRecordUseCase(
            repository: store,
            clock: FixedClock(date: instant),
            calendarProvider: FixedCalendarProvider(
                value: calendar(timeZoneID: "America/Los_Angeles")
            ),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(3))
        )
        let currentRecord = try await useCase.execute(
            taskKind: .automaticDaily,
            plannedSourceID: nil
        )

        let archived = try #require(
            try await store.record(for: shanghaiDay, taskKind: .automaticDaily)
        )
        #expect(archived.status == .failed)
        #expect(archived.automaticAttemptCount == 2)
        #expect(archived.nextRetryAt == nil)
        #expect(currentRecord.localDay == losAngelesDay)
        #expect(currentRecord.status == .pending)
    }

    @Test("A repeated event preserves the completed canonical record", arguments: Backend.allCases)
    func repeatedEventPreservesCompletedRecord(backend: Backend) async throws {
        let store = try makeStore(backend)
        let instant = Date(timeIntervalSince1970: 1_787_097_600)
        let localCalendar = calendar(timeZoneID: "Asia/Shanghai")
        let day = LocalDay(containing: instant, calendar: localCalendar)
        var completed = try await store.prepareRecord(
            for: day,
            taskKind: .automaticDaily,
            id: DailyFetchRecordID(rawValue: fixedUUID(9)),
            plannedSourceID: SourceID(rawValue: fixedUUID(10))
        )
        completed.status = .success
        completed.automaticAttemptCount = 1
        completed.actualSourceID = SourceID(rawValue: fixedUUID(11))
        completed.wallpaperID = WallpaperID(rawValue: fixedUUID(12))
        completed.lastAttemptAt = instant.addingTimeInterval(-60)
        try await store.save(completed)

        let useCase = PrepareDailyFetchRecordUseCase(
            repository: store,
            clock: FixedClock(date: instant),
            calendarProvider: FixedCalendarProvider(value: localCalendar),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(13))
        )
        let repeated = try await useCase.execute(
            taskKind: .automaticDaily,
            plannedSourceID: SourceID(rawValue: fixedUUID(14))
        )

        #expect(repeated == completed)
        #expect(try await store.allRecords().count == 1)
    }

    @Test("A next-day manual event archives the stale automatic retry", arguments: Backend.allCases)
    func nextDayManualEventArchivesStaleAutomaticRetry(backend: Backend) async throws {
        let store = try makeStore(backend)
        let previousDay = try #require(LocalDay(rawValue: "2026-08-18"))
        let currentDay = try #require(LocalDay(rawValue: "2026-08-19"))
        var stale = try await store.prepareRecord(
            for: previousDay,
            taskKind: .automaticDaily,
            id: DailyFetchRecordID(rawValue: fixedUUID(15)),
            plannedSourceID: nil
        )
        stale.status = .retryScheduled
        stale.automaticAttemptCount = 2
        stale.nextRetryAt = Date(timeIntervalSince1970: 1_787_099_400)
        try await store.save(stale)

        let manual = try await store.prepareRecord(
            for: currentDay,
            taskKind: .manualUpdate,
            id: DailyFetchRecordID(rawValue: fixedUUID(16)),
            plannedSourceID: nil
        )
        let archived = try #require(
            try await store.record(for: previousDay, taskKind: .automaticDaily)
        )

        #expect(manual.taskKind == .manualUpdate)
        #expect(manual.automaticAttemptCount == 0)
        #expect(archived.status == .failed)
        #expect(archived.automaticAttemptCount == 2)
        #expect(archived.nextRetryAt == nil)
    }

    @Test("Manual preparation never changes automatic attempt state", arguments: Backend.allCases)
    func manualAttemptIsIsolated(backend: Backend) async throws {
        let store = try makeStore(backend)
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        var automatic = try await store.prepareRecord(
            for: day,
            taskKind: .automaticDaily,
            id: DailyFetchRecordID(rawValue: fixedUUID(4)),
            plannedSourceID: nil
        )
        automatic.status = .retryScheduled
        automatic.automaticAttemptCount = 2
        automatic.nextRetryAt = Date(timeIntervalSince1970: 1_787_099_400)
        try await store.save(automatic)

        let manual = try await store.prepareRecord(
            for: day,
            taskKind: .manualUpdate,
            id: DailyFetchRecordID(rawValue: fixedUUID(5)),
            plannedSourceID: nil
        )
        let persistedAutomatic = try #require(
            try await store.record(for: day, taskKind: .automaticDaily)
        )

        #expect(manual.id != persistedAutomatic.id)
        #expect(manual.taskKind == .manualUpdate)
        #expect(manual.automaticAttemptCount == 0)
        #expect(persistedAutomatic.automaticAttemptCount == 2)
        #expect(persistedAutomatic.status == .retryScheduled)
    }

    @Test("Retry due checks require the same automatic local day")
    func retryDueRequiresSameDay() throws {
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let otherDay = try #require(LocalDay(rawValue: "2026-08-20"))
        let dueAt = Date(timeIntervalSince1970: 1_787_099_400)
        var record = DailyFetchRecord.pending(
            id: DailyFetchRecordID(rawValue: fixedUUID(6)),
            day: day,
            taskKind: .automaticDaily,
            plannedSourceID: nil
        )
        record.status = .retryScheduled
        record.automaticAttemptCount = 1
        record.nextRetryAt = dueAt

        #expect(record.isAutomaticRetryDue(at: dueAt, on: day))
        #expect(!record.isAutomaticRetryDue(at: dueAt.addingTimeInterval(-1), on: day))
        #expect(!record.isAutomaticRetryDue(at: dueAt, on: otherDay))

        let manual = DailyFetchRecord(
            id: record.id,
            taskKey: DailyFetchRecord.taskKey(for: day, taskKind: .manualUpdate),
            localDay: day,
            taskKind: .manualUpdate,
            plannedSourceID: nil,
            actualSourceID: nil,
            status: .retryScheduled,
            automaticAttemptCount: 0,
            usedDefaultSource: false,
            wallpaperID: nil,
            lastAttemptAt: nil,
            nextRetryAt: dueAt,
            lastErrorCode: nil
        )
        #expect(!manual.isAutomaticRetryDue(at: dueAt, on: day))
    }

    @Test("A disk store restores automatic retry state after reopening")
    func processRestartRestoresRetry() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "zikora-p02-daily-fetch-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storeURL = rootURL.appendingPathComponent("ZIKORA.store")
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let retryAt = Date(timeIntervalSince1970: 1_787_099_400)
        try await seedRetryStore(at: storeURL, day: day, retryAt: retryAt)

        let reopenedContainer = try PersistenceContainerFactory.makeStore(at: storeURL)
        let reopenedStore = SwiftDataRepositoryStore(modelContainer: reopenedContainer)
        let restored = try #require(
            try await reopenedStore.record(for: day, taskKind: .automaticDaily)
        )

        #expect(restored.status == .retryScheduled)
        #expect(restored.automaticAttemptCount == 2)
        #expect(restored.nextRetryAt == retryAt)
        #expect(restored.isAutomaticRetryDue(at: retryAt, on: day))
    }

    private func seedRetryStore(at storeURL: URL, day: LocalDay, retryAt: Date) async throws {
        let container = try PersistenceContainerFactory.makeStore(at: storeURL)
        let store = SwiftDataRepositoryStore(modelContainer: container)
        var record = try await store.prepareRecord(
            for: day,
            taskKind: .automaticDaily,
            id: DailyFetchRecordID(rawValue: fixedUUID(7)),
            plannedSourceID: SourceID(rawValue: fixedUUID(8))
        )
        record.status = .retryScheduled
        record.automaticAttemptCount = 2
        record.lastAttemptAt = retryAt.addingTimeInterval(-7_200)
        record.nextRetryAt = retryAt
        record.lastErrorCode = .requestTimedOut
        try await store.save(record)
    }

    private func makeStore(_ backend: Backend) throws -> any RepositoryStore {
        switch backend {
        case .inMemory:
            try InMemoryRepositoryStore()
        case .swiftData:
            SwiftDataRepositoryStore(
                modelContainer: try PersistenceContainerFactory.makeInMemoryStore()
            )
        }
    }

    nonisolated private func calendar(timeZoneID: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(identifier: timeZoneID) else {
            preconditionFailure("Test time zone must be available")
        }
        value.timeZone = timeZone
        return value
    }

    nonisolated private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
