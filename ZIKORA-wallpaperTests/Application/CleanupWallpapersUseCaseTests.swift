import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct CleanupWallpapersUseCaseTests {
    @Test("Retention cutoff is exact and forever keeps healthy history")
    func plansRetentionBoundary() throws {
        let today = try #require(LocalDay(rawValue: "2026-08-19"))
        let calendar = calendar(timeZoneID: "Asia/Shanghai")
        let current = try wallpaper(id: 1, day: "2026-01-01", state: .available, current: true)
        let boundary = try wallpaper(id: 2, day: "2026-08-12", state: .available)
        let expired = try wallpaper(id: 3, day: "2026-08-11", state: .available)
        let damaged = try wallpaper(id: 4, day: "2026-08-18", state: .missing)

        let sevenDay = WallpaperCleanupPlanner.estimate(
            wallpapers: [current, boundary, expired, damaged],
            inventory: [],
            today: today,
            policy: .sevenDays,
            calendar: calendar
        )
        #expect(sevenDay.candidates.map(\.wallpaperID) == [expired.id, damaged.id])

        let forever = WallpaperCleanupPlanner.estimate(
            wallpapers: [current, boundary, expired, damaged],
            inventory: [],
            today: today,
            policy: .forever,
            calendar: calendar
        )
        #expect(forever.candidates.map(\.wallpaperID) == [damaged.id])
    }

    @Test("Planner reports orphan files without treating current wallpaper as removable")
    func protectsCurrentAndFindsOrphans() throws {
        let today = try #require(LocalDay(rawValue: "2026-08-19"))
        let current = try wallpaper(id: 10, day: "2026-01-01", state: .available, current: true)
        let old = try wallpaper(id: 11, day: "2026-01-01", state: .available)
        let orphan = try #require(ManagedRelativePath(rawValue: "2026-01-01/orphan.png"))
        let estimate = WallpaperCleanupPlanner.estimate(
            wallpapers: [current, old],
            inventory: [current.relativePath, old.relativePath, orphan],
            today: today,
            policy: .sevenDays,
            calendar: calendar(timeZoneID: "UTC")
        )

        #expect(estimate.candidates.map(\.wallpaperID) == [old.id])
        #expect(estimate.orphanPaths == [orphan])
        #expect(estimate.byteCount == old.fileSize)
    }

    @Test("Execution requires explicit confirmation")
    func requiresConfirmation() async throws {
        let repository = try InMemoryRepositoryStore()
        let fileStore = RecordingCleanupFileStore()
        let inventory = RecordingCleanupInventory(paths: [])
        let useCase = CleanupWallpapersUseCase(
            wallpapers: repository,
            fileStore: fileStore,
            fileInventory: inventory
        )

        await #expect(throws: WallpaperCleanupExecutionError.confirmationRequired) {
            try await useCase.execute(
                policy: .sevenDays,
                today: try #require(LocalDay(rawValue: "2026-08-19")),
                calendar: calendar(timeZoneID: "UTC"),
                confirmed: false
            )
        }
        #expect(await fileStore.removedPaths.isEmpty)
    }

    @Test("Execution deletes files before records and reports partial failures")
    func executesWithPartialFailureReport() async throws {
        let old = try wallpaper(id: 20, day: "2026-01-01", state: .available)
        let damaged = try wallpaper(id: 21, day: "2026-01-02", state: .missing)
        let orphan = try #require(ManagedRelativePath(rawValue: "orphan/unknown.png"))
        let repository = try InMemoryRepositoryStore(wallpapers: [old, damaged])
        let fileStore = RecordingCleanupFileStore(failingPaths: [damaged.relativePath])
        let inventory = RecordingCleanupInventory(paths: [old.relativePath, damaged.relativePath, orphan])
        let useCase = CleanupWallpapersUseCase(
            wallpapers: repository,
            fileStore: fileStore,
            fileInventory: inventory
        )

        let report = try await useCase.execute(
            policy: .sevenDays,
            today: try #require(LocalDay(rawValue: "2026-08-19")),
            calendar: calendar(timeZoneID: "UTC"),
            confirmed: true
        )

        #expect(report.deletedWallpaperIDs == [old.id])
        #expect(report.deletedOrphanPaths == [orphan])
        #expect(report.failedWallpaperIDs == [damaged.id])
        #expect(report.remainingStatistics == FileStoreStatistics(fileCount: 0, byteCount: 0))
        #expect(try await repository.wallpaper(id: old.id) == nil)
        #expect(try await repository.wallpaper(id: damaged.id) != nil)
        #expect(await fileStore.removedPaths == [old.relativePath.rawValue, damaged.relativePath.rawValue, orphan.rawValue])
    }

    @Test("Invalid and missing records are eligible even under forever retention")
    func damagedRecordsAreAlwaysEligible() throws {
        let today = try #require(LocalDay(rawValue: "2026-08-19"))
        let invalid = try wallpaper(id: 30, day: "2026-08-19", state: .invalid)
        let missing = try wallpaper(id: 31, day: "2026-08-19", state: .missing)
        let estimate = WallpaperCleanupPlanner.estimate(
            wallpapers: [invalid, missing],
            inventory: [],
            today: today,
            policy: .forever,
            calendar: calendar(timeZoneID: "UTC")
        )
        #expect(estimate.candidates.count == 2)
        #expect(estimate.candidates.allSatisfy { $0.reasons == [.damaged] })
    }

    private func wallpaper(
        id: UInt8,
        day: String,
        state: WallpaperFileState,
        current: Bool = false
    ) throws -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(id)),
            contentHash: "cleanup-hash-\(id)",
            sourceID: nil,
            sourceNameSnapshot: "Cleanup fixture",
            relativePath: try #require(ManagedRelativePath(rawValue: "\(day)/\(id).png")),
            downloadDay: try #require(LocalDay(rawValue: day)),
            createdAt: Date(timeIntervalSince1970: 1_787_000_000),
            pixelWidth: 100,
            pixelHeight: 100,
            fileSize: 100 + Int64(id),
            format: .png,
            fileState: state,
            isCurrent: current
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID)!
        return value
    }
}

private actor RecordingCleanupFileStore: WallpaperFileStore {
    private let failingPaths: Set<ManagedRelativePath>
    private(set) var removedPaths: [String] = []

    init(failingPaths: Set<ManagedRelativePath> = []) {
        self.failingPaths = failingPaths
    }

    func commitTemporaryFile(at _: URL, preferredExtension _: String) async throws -> String {
        throw AppFailure(code: .fileOperationFailed)
    }

    func remove(relativePath: String) async throws {
        removedPaths.append(relativePath)
        guard let path = ManagedRelativePath(rawValue: relativePath), !failingPaths.contains(path) else {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    func statistics() async throws -> FileStoreStatistics {
        FileStoreStatistics(fileCount: 0, byteCount: 0)
    }
}

private actor RecordingCleanupInventory: ManagedFileInventoryProviding {
    let paths: Set<ManagedRelativePath>

    init(paths: Set<ManagedRelativePath>) { self.paths = paths }

    func inventory() async throws -> Set<ManagedRelativePath> { paths }
}
