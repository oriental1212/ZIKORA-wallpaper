import Foundation
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct RepositoryStoreTests {
    enum Backend: String, CaseIterable, Sendable {
        case inMemory
        case swiftData
    }

    @Test("Both repository backends implement CRUD, lookup, sorting, and file state", arguments: Backend.allCases)
    func repositoryContract(backend: Backend) async throws {
        let store = try makeStore(backend)
        let fixture = try makeFixture()

        try await store.save(fixture.newerSource)
        try await store.save(fixture.olderSource)
        #expect(try await store.allSources().map(\.id) == [
            fixture.olderSource.id,
            fixture.newerSource.id,
        ])
        #expect(try await store.source(id: fixture.newerSource.id) == fixture.newerSource)

        try await store.save(fixture.schedule)
        try await store.save(fixture.settings)
        #expect(try await store.loadSchedule() == fixture.schedule)
        #expect(try await store.loadSettings() == fixture.settings)

        try await store.save(fixture.olderWallpaper)
        try await store.save(fixture.newerWallpaper)
        #expect(try await store.allWallpapers().map(\.id) == [
            fixture.newerWallpaper.id,
            fixture.olderWallpaper.id,
        ])
        #expect(try await store.wallpaper(
            contentHash: fixture.newerWallpaper.contentHash
        )?.id == fixture.newerWallpaper.id)

        try await store.markFileState(id: fixture.newerWallpaper.id, state: .missing)
        #expect(try await store.wallpaper(id: fixture.newerWallpaper.id)?.fileState == .missing)

        try await store.save(fixture.record)
        #expect(try await store.allRecords() == [fixture.record])
        #expect(try await store.record(
            for: fixture.record.localDay,
            taskKind: .automaticDaily
        ) == fixture.record)
    }

    @Test("Duplicate keys roll back without mutating existing records", arguments: Backend.allCases)
    func duplicateRollback(backend: Backend) async throws {
        let store = try makeStore(backend)
        let fixture = try makeFixture()
        try await store.save(fixture.olderWallpaper)
        try await store.save(fixture.newerWallpaper)

        let conflictingWallpaper = Wallpaper(
            id: fixture.olderWallpaper.id,
            contentHash: fixture.newerWallpaper.contentHash,
            sourceID: nil,
            sourceNameSnapshot: "Must not persist",
            relativePath: fixture.olderWallpaper.relativePath,
            downloadDay: fixture.olderWallpaper.downloadDay,
            createdAt: fixture.olderWallpaper.createdAt,
            pixelWidth: 10,
            pixelHeight: 10,
            fileSize: 10,
            format: .png,
            fileState: .invalid,
            isCurrent: false
        )

        await #expect(throws: RepositoryError.duplicateContentHash) {
            try await store.save(conflictingWallpaper)
        }
        #expect(try await store.wallpaper(id: fixture.olderWallpaper.id) == fixture.olderWallpaper)

        try await store.save(fixture.record)
        var duplicateRecord = fixture.record
        duplicateRecord = DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(99)),
            taskKey: fixture.record.taskKey,
            localDay: duplicateRecord.localDay,
            taskKind: duplicateRecord.taskKind,
            plannedSourceID: nil,
            actualSourceID: nil,
            status: .failed,
            automaticAttemptCount: 3,
            usedDefaultSource: true,
            wallpaperID: nil,
            lastAttemptAt: duplicateRecord.lastAttemptAt,
            nextRetryAt: nil,
            lastErrorCode: .unknown
        )
        await #expect(throws: RepositoryError.duplicateTaskKey) {
            try await store.save(duplicateRecord)
        }
        #expect(try await store.allRecords() == [fixture.record])
    }

    @Test("Concurrent source saves are serialized and deterministically sorted", arguments: Backend.allCases)
    func concurrentSaves(backend: Backend) async throws {
        let store = try makeStore(backend)
        let url = try #require(URL(string: "https://example.invalid/wallpaper.png"))
        let baseDate = Date(timeIntervalSince1970: 1_787_000_000)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let source = WallpaperSource(
                        id: SourceID(rawValue: self.fixedUUID(UInt8(index + 1))),
                        name: "Source \(index)",
                        url: url,
                        isEnabled: true,
                        createdAt: baseDate.addingTimeInterval(Double(index)),
                        updatedAt: baseDate,
                        lastFetchAt: nil,
                        lastFetchStatus: .never,
                        lastErrorCode: nil,
                        lastErrorMessage: nil,
                        consecutiveFailureDays: 0
                    )
                    try await store.save(source)
                }
            }
            try await group.waitForAll()
        }

        let sources = try await store.allSources()
        #expect(sources.count == 20)
        #expect(sources.map(\.createdAt) == sources.map(\.createdAt).sorted())
    }

    @Test("Deleting a source clears references atomically and preserves history", arguments: Backend.allCases)
    func deleteSourceTransaction(backend: Backend) async throws {
        let store = try makeStore(backend)
        let fixture = try makeFixture()
        try await store.save(fixture.olderSource)
        try await store.save(fixture.olderWallpaper)
        try await store.save(fixture.schedule)
        try await store.save(fixture.record)

        let deletedAt = fixture.schedule.updatedAt.addingTimeInterval(60)
        try await store.delete(
            id: fixture.olderSource.id,
            scheduleUpdatedAt: deletedAt
        )

        #expect(try await store.source(id: fixture.olderSource.id) == nil)
        let wallpaper = try #require(try await store.wallpaper(id: fixture.olderWallpaper.id))
        #expect(wallpaper.sourceID == nil)
        #expect(wallpaper.sourceNameSnapshot == fixture.olderWallpaper.sourceNameSnapshot)
        #expect(try await store.loadSchedule()?.mondaySourceID == nil)
        #expect(try await store.loadSchedule()?.defaultSourceID == nil)
        #expect(try await store.loadSchedule()?.updatedAt == deletedAt)
        #expect(try await store.allRecords().first?.plannedSourceID == nil)
        #expect(try await store.allRecords().first?.actualSourceID == nil)
    }

    @Test("Missing entities produce classified repository errors", arguments: Backend.allCases)
    func classifiedErrors(backend: Backend) async throws {
        let store = try makeStore(backend)
        let missingID = WallpaperID(rawValue: fixedUUID(200))

        await #expect(throws: RepositoryError.notFound(entity: .wallpaper)) {
            try await store.markFileState(id: missingID, state: .missing)
        }
        await #expect(throws: RepositoryError.notFound(entity: .wallpaper)) {
            try await store.markCurrent(id: missingID)
        }
    }

    @Test("Corrupt persisted raw values are classified instead of escaping to callers")
    func corruptPersistenceValue() async throws {
        let container = try PersistenceContainerFactory.makeInMemoryStore()
        let context = ModelContext(container)
        let sourceURL = try #require(URL(string: "https://example.invalid/wallpaper.png"))
        let now = Date(timeIntervalSince1970: 1_787_097_600)
        let value = PersistedWallpaperSource(
            id: SourceID(rawValue: fixedUUID(1)),
            name: "Corrupt",
            url: sourceURL,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
        value.lastFetchStatusRaw = "not-a-status"
        context.insert(value)
        try context.save()

        let store = SwiftDataRepositoryStore(modelContainer: container)
        await #expect(throws: RepositoryError.invalidPersistedValue(
            entity: .source,
            field: "lastFetchStatus"
        )) {
            try await store.allSources()
        }
    }

    private struct Fixture {
        let olderSource: WallpaperSource
        let newerSource: WallpaperSource
        let olderWallpaper: Wallpaper
        let newerWallpaper: Wallpaper
        let schedule: WeeklySchedule
        let settings: UserSettings
        let record: DailyFetchRecord
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

    private func makeFixture() throws -> Fixture {
        let olderDate = Date(timeIntervalSince1970: 1_787_000_000)
        let newerDate = olderDate.addingTimeInterval(60)
        let olderSourceID = SourceID(rawValue: fixedUUID(1))
        let newerSourceID = SourceID(rawValue: fixedUUID(2))
        let sourceURL = try #require(URL(string: "https://example.invalid/wallpaper.png"))
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let olderPath = try #require(ManagedRelativePath(rawValue: "Wallpapers/older.png"))
        let newerPath = try #require(ManagedRelativePath(rawValue: "Wallpapers/newer.png"))

        let olderSource = WallpaperSource(
            id: olderSourceID,
            name: "Older",
            url: sourceURL,
            isEnabled: true,
            createdAt: olderDate,
            updatedAt: olderDate,
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
        let newerSource = WallpaperSource(
            id: newerSourceID,
            name: "Newer",
            url: sourceURL,
            isEnabled: true,
            createdAt: newerDate,
            updatedAt: newerDate,
            lastFetchAt: newerDate,
            lastFetchStatus: .success,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
        let olderWallpaper = Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(10)),
            contentHash: "older-hash",
            sourceID: olderSourceID,
            sourceNameSnapshot: olderSource.name,
            relativePath: olderPath,
            downloadDay: day,
            createdAt: olderDate,
            pixelWidth: 100,
            pixelHeight: 100,
            fileSize: 100,
            format: .jpeg,
            fileState: .available,
            isCurrent: true
        )
        let newerWallpaper = Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(11)),
            contentHash: "newer-hash",
            sourceID: newerSourceID,
            sourceNameSnapshot: newerSource.name,
            relativePath: newerPath,
            downloadDay: day,
            createdAt: newerDate,
            pixelWidth: 200,
            pixelHeight: 100,
            fileSize: 200,
            format: .png,
            fileState: .available,
            isCurrent: false
        )
        let schedule = WeeklySchedule(
            id: fixedUUID(20),
            mondaySourceID: olderSourceID,
            tuesdaySourceID: newerSourceID,
            wednesdaySourceID: nil,
            thursdaySourceID: nil,
            fridaySourceID: nil,
            saturdaySourceID: nil,
            sundaySourceID: nil,
            defaultSourceID: olderSourceID,
            updatedAt: newerDate
        )
        let settings = UserSettings.defaults(id: fixedUUID(21), updatedAt: newerDate)
        let record = DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(22)),
            taskKey: "2026-08-19|automatic_daily",
            localDay: day,
            taskKind: .automaticDaily,
            plannedSourceID: olderSourceID,
            actualSourceID: olderSourceID,
            status: .retryScheduled,
            automaticAttemptCount: 1,
            usedDefaultSource: false,
            wallpaperID: olderWallpaper.id,
            lastAttemptAt: newerDate,
            nextRetryAt: newerDate.addingTimeInterval(30 * 60),
            lastErrorCode: .requestTimedOut
        )

        return Fixture(
            olderSource: olderSource,
            newerSource: newerSource,
            olderWallpaper: olderWallpaper,
            newerWallpaper: newerWallpaper,
            schedule: schedule,
            settings: settings,
            record: record
        )
    }

    nonisolated private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
