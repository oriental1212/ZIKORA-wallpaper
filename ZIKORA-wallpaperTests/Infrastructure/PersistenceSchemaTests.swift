import Foundation
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct PersistenceSchemaTests {
    @Test("V1 schema declares all five entities and an explicit migration baseline")
    func schemaVersion() {
        #expect(ZIKORASchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(PersistenceContainerFactory.currentSchema.entities.count == 5)
        #expect(ZIKORAMigrationPlan.schemas.count == 1)
        #expect(ZIKORAMigrationPlan.stages.isEmpty)
    }

    @Test("An empty disk store initializes all entity tables")
    func emptyStoreInitialization() throws {
        try withTemporaryStore { storeURL in
            let container = try PersistenceContainerFactory.makeStore(at: storeURL)
            let context = ModelContext(container)

            #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaperSource>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaper>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<PersistedWeeklySchedule>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<PersistedUserSettings>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<PersistedDailyFetchRecord>()) == 0)
        }
    }

    @Test("Reopening restores current wallpaper, retry state, schedule, and settings")
    func reopenRestoresState() throws {
        try withTemporaryStore { storeURL in
            let fixture = try seedStore(at: storeURL)
            let container = try PersistenceContainerFactory.makeStore(at: storeURL)
            let context = ModelContext(container)

            let wallpapers = try context.fetch(FetchDescriptor<PersistedWallpaper>())
            let records = try context.fetch(FetchDescriptor<PersistedDailyFetchRecord>())
            let schedules = try context.fetch(FetchDescriptor<PersistedWeeklySchedule>())
            let settings = try context.fetch(FetchDescriptor<PersistedUserSettings>())

            #expect(wallpapers.count == 1)
            #expect(wallpapers.first?.id == fixture.wallpaperID.rawValue)
            #expect(wallpapers.first?.isCurrent == true)
            #expect(wallpapers.first?.relativePath == "Wallpapers/2026-08-19/wallpaper.png")
            #expect(records.first?.automaticAttemptCount == 2)
            #expect(records.first?.nextRetryAt == fixture.retryDate)
            #expect(records.first?.wallpaperID == fixture.wallpaperID.rawValue)
            #expect(schedules.first?.mondaySourceID == fixture.sourceID.rawValue)
            #expect(settings.first?.wallpaperModeRaw == WallpaperMode.slideshow.rawValue)
            #expect(settings.first?.retentionPolicyRaw == RetentionPolicy.sixtyDays.rawValue)
        }
    }

    @Test("Deleting a source keeps wallpaper history and safe ID snapshots")
    func sourceDeletionKeepsHistory() throws {
        try withTemporaryStore { storeURL in
            let fixture = try seedStore(at: storeURL)
            let container = try PersistenceContainerFactory.makeStore(at: storeURL)
            let context = ModelContext(container)
            let sources = try context.fetch(FetchDescriptor<PersistedWallpaperSource>())

            let source = try #require(sources.first)
            context.delete(source)
            try context.save()

            #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaperSource>()) == 0)
            let wallpaper = try #require(context.fetch(FetchDescriptor<PersistedWallpaper>()).first)
            let schedule = try #require(context.fetch(FetchDescriptor<PersistedWeeklySchedule>()).first)
            #expect(wallpaper.sourceID == fixture.sourceID.rawValue)
            #expect(wallpaper.sourceNameSnapshot == "Fixture Source")
            #expect(schedule.defaultSourceID == fixture.sourceID.rawValue)
        }
    }

    @Test("Content hash and daily task key enforce unique queries")
    func uniqueKeys() throws {
        let container = try PersistenceContainerFactory.makeInMemoryStore()
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_787_097_600)
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let path = try #require(ManagedRelativePath(rawValue: "Wallpapers/one.png"))

        context.insert(PersistedWallpaper(
            id: WallpaperID(rawValue: fixedUUID(10)),
            contentHash: "same-content-hash",
            sourceID: nil,
            sourceNameSnapshot: "First",
            relativePath: path,
            downloadDay: day,
            createdAt: now,
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 100,
            format: .png
        ))
        try context.save()

        context.insert(PersistedWallpaper(
            id: WallpaperID(rawValue: fixedUUID(11)),
            contentHash: "same-content-hash",
            sourceID: nil,
            sourceNameSnapshot: "Second",
            relativePath: path,
            downloadDay: day,
            createdAt: now,
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 100,
            format: .png
        ))

        do {
            try context.save()
            #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaper>()) == 1)
        } catch {
            context.rollback()
            #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaper>()) <= 1)
        }

        let recordContext = ModelContext(container)
        recordContext.insert(PersistedDailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(20)),
            taskKey: "2026-08-19|automatic_daily",
            localDay: day,
            taskKind: .automaticDaily
        ))
        try recordContext.save()

        recordContext.insert(PersistedDailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(21)),
            taskKey: "2026-08-19|automatic_daily",
            localDay: day,
            taskKind: .automaticDaily
        ))

        do {
            try recordContext.save()
            #expect(try recordContext.fetchCount(FetchDescriptor<PersistedDailyFetchRecord>()) == 1)
        } catch {
            recordContext.rollback()
            #expect(try recordContext.fetchCount(FetchDescriptor<PersistedDailyFetchRecord>()) <= 1)
        }
    }

    @Test("Managed paths reject absolute paths and traversal")
    func managedRelativePaths() throws {
        let valid = try #require(ManagedRelativePath(
            rawValue: "Wallpapers/2026-08-19/source_hash.png"
        ))
        let encoded = try JSONEncoder().encode(valid)

        #expect(try JSONDecoder().decode(ManagedRelativePath.self, from: encoded) == valid)
        #expect(ManagedRelativePath(rawValue: "/tmp/wallpaper.png") == nil)
        #expect(ManagedRelativePath(rawValue: "../wallpaper.png") == nil)
        #expect(ManagedRelativePath(rawValue: "Wallpapers/../outside.png") == nil)
        #expect(ManagedRelativePath(rawValue: "Wallpapers//wallpaper.png") == nil)
        #expect(ManagedRelativePath(rawValue: "Wallpapers\\wallpaper.png") == nil)
    }

    private struct Fixture {
        let sourceID: SourceID
        let wallpaperID: WallpaperID
        let retryDate: Date
    }

    private func seedStore(at storeURL: URL) throws -> Fixture {
        let container = try PersistenceContainerFactory.makeStore(at: storeURL)
        let context = ModelContext(container)
        let sourceID = SourceID(rawValue: fixedUUID(1))
        let wallpaperID = WallpaperID(rawValue: fixedUUID(2))
        let now = Date(timeIntervalSince1970: 1_787_097_600)
        let retryDate = now.addingTimeInterval(30 * 60)
        let sourceURL = try #require(URL(string: "https://example.invalid/wallpaper.png"))
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let path = try #require(ManagedRelativePath(
            rawValue: "Wallpapers/2026-08-19/wallpaper.png"
        ))

        context.insert(PersistedWallpaperSource(
            id: sourceID,
            name: "Fixture Source",
            url: sourceURL,
            isEnabled: true,
            createdAt: now,
            updatedAt: now,
            lastFetchAt: now,
            lastFetchStatus: .success
        ))
        context.insert(PersistedWallpaper(
            id: wallpaperID,
            contentHash: "fixture-content-hash",
            sourceID: sourceID,
            sourceNameSnapshot: "Fixture Source",
            relativePath: path,
            downloadDay: day,
            createdAt: now,
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 100,
            format: .png,
            isCurrent: true
        ))
        context.insert(PersistedWeeklySchedule(
            id: fixedUUID(3),
            mondaySourceID: sourceID,
            defaultSourceID: sourceID,
            updatedAt: now
        ))
        context.insert(PersistedUserSettings(
            id: fixedUUID(4),
            wallpaperMode: .slideshow,
            retentionPolicy: .sixtyDays,
            slideshowOrder: .chronological,
            slideshowInterval: .oneHour,
            onboardingCompleted: true,
            lastSelectedNavigation: .library,
            updatedAt: now
        ))
        context.insert(PersistedDailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(5)),
            taskKey: "2026-08-19|automatic_daily",
            localDay: day,
            taskKind: .automaticDaily,
            plannedSourceID: sourceID,
            actualSourceID: sourceID,
            status: .retryScheduled,
            automaticAttemptCount: 2,
            usedDefaultSource: false,
            wallpaperID: wallpaperID,
            lastAttemptAt: now,
            nextRetryAt: retryDate,
            lastErrorCode: .requestTimedOut
        ))
        try context.save()

        return Fixture(sourceID: sourceID, wallpaperID: wallpaperID, retryDate: retryDate)
    }

    private func withTemporaryStore(_ body: (URL) throws -> Void) throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "zikora-p02-schema-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try body(rootURL.appendingPathComponent("ZIKORA.store"))
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
