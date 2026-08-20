import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct DeduplicateWallpaperUseCaseTests {
    @Test("Different URLs with identical bytes reuse one wallpaper")
    func identicalContentUsesExistingWallpaper() async throws {
        let store = try InMemoryRepositoryStore()
        let firstURL = try temporaryFile(named: "first", contents: Data("same-image".utf8))
        let secondURL = try temporaryFile(named: "second", contents: Data("same-image".utf8))
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let hasher = SHA256ImageHasher(chunkSize: 2)
        let firstHash = try await hasher.hash(fileAt: firstURL)
        let existing = try makeWallpaper(hash: firstHash.value, isCurrent: false)
        try await store.save(existing)

        let decision = try await DeduplicateWallpaperUseCase(
            wallpapers: store,
            hasher: hasher
        ).execute(fileAt: secondURL)

        #expect(decision.contentHash == firstHash)
        #expect(decision.existingWallpaper?.id == existing.id)
        #expect(decision.reusesExistingWallpaper)
    }

    @Test("The same URL with changed bytes receives a new content identity")
    func changedContentAtSameURLIsNotDuplicate() async throws {
        let store = try InMemoryRepositoryStore()
        let fileURL = try temporaryFile(named: "mutable", contents: Data("first-image".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let useCase = DeduplicateWallpaperUseCase(wallpapers: store)

        let first = try await useCase.execute(fileAt: fileURL)
        try Data("second-image".utf8).write(to: fileURL, options: .atomic)
        let second = try await useCase.execute(fileAt: fileURL)

        #expect(first.contentHash != second.contentHash)
        #expect(!second.reusesExistingWallpaper)
    }

    @Test("Repeated manual updates reuse the existing physical wallpaper")
    func repeatedManualUpdateReusesWallpaper() async throws {
        let store = try InMemoryRepositoryStore()
        let fileURL = try temporaryFile(named: "manual", contents: Data("manual-image".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let useCase = DeduplicateWallpaperUseCase(wallpapers: store)

        let first = try await useCase.execute(fileAt: fileURL)
        let wallpaper = try makeWallpaper(hash: first.contentHash.value, isCurrent: true)
        try await store.save(wallpaper)
        let repeated = try await useCase.execute(fileAt: fileURL)

        #expect(repeated.existingWallpaper?.id == wallpaper.id)
        #expect(repeated.matchesCurrentWallpaper)
    }

    @Test("A reused wallpaper is linked to the daily fetch record")
    func associatesDailyRecordWithReusedWallpaper() async throws {
        let store = try InMemoryRepositoryStore()
        let wallpaper = try makeWallpaper(hash: "hash-for-link", isCurrent: false)
        try await store.save(wallpaper)
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let record = DailyFetchRecord.pending(
            id: DailyFetchRecordID(rawValue: fixedUUID(20)),
            day: day,
            taskKind: .manualUpdate,
            plannedSourceID: nil
        )

        let completed = try await AssociateWallpaperWithFetchUseCase(records: store).execute(
            record: record,
            wallpaper: wallpaper,
            actualSourceID: SourceID(rawValue: fixedUUID(21)),
            attemptedAt: Date(timeIntervalSince1970: 1_787_000_000)
        )

        #expect(completed.status == .success)
        #expect(completed.wallpaperID == wallpaper.id)
        #expect(try await store.allRecords() == [completed])
    }

    private func temporaryFile(named name: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dedup-\(name)-\(UUID().uuidString).bin")
        try contents.write(to: url, options: .atomic)
        return url
    }

    private func makeWallpaper(hash: String, isCurrent: Bool) throws -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(10)),
            contentHash: hash,
            sourceID: nil,
            sourceNameSnapshot: "Fixture",
            relativePath: try #require(ManagedRelativePath(rawValue: "Wallpapers/fixture.png")),
            downloadDay: try #require(LocalDay(rawValue: "2026-08-19")),
            createdAt: Date(timeIntervalSince1970: 1_787_000_000),
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 10,
            format: .png,
            fileState: .available,
            isCurrent: isCurrent
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
