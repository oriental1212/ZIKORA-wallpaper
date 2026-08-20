import Foundation
import os
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct MaintainWallpaperFilesUseCaseTests {
    @Test("Maintenance marks missing records, restores returned files, and preserves unknown files")
    func reconcilesWithoutDeletingUnknownFiles() async throws {
        let available = try wallpaper(id: 1, path: "2026-08-19/available.png", state: .available)
        let missing = try wallpaper(id: 2, path: "2026-08-19/missing.png", state: .available)
        let restored = try wallpaper(id: 3, path: "2026-08-18/restored.png", state: .missing)
        let unknown = try #require(ManagedRelativePath(rawValue: "manual/keep-me.png"))
        let store = try InMemoryRepositoryStore(wallpapers: [available, missing, restored])
        let inventory = RecordingFileInventory(paths: [
            available.relativePath,
            restored.relativePath,
            unknown,
        ])
        let logger = RecordingMaintenanceLogger()
        let report = try await MaintainWallpaperFilesUseCase(
            wallpapers: store,
            fileInventory: inventory,
            logger: logger
        ).execute()

        #expect(report.inspectedRecordCount == 3)
        #expect(report.missingRecordIDs == [missing.id])
        #expect(report.restoredRecordIDs == [restored.id])
        #expect(report.unknownRelativePaths == [unknown])
        #expect(report.hasInconsistencies)
        #expect(try await store.wallpaper(id: available.id)?.fileState == .available)
        #expect(try await store.wallpaper(id: missing.id)?.fileState == .missing)
        #expect(try await store.wallpaper(id: restored.id)?.fileState == .available)
        #expect(await inventory.inventoryCallCount == 1)
        #expect(logger.records.last?.event == .inconsistencyDetected)
    }

    @Test("A missing current file is retained as current but excluded by file state")
    func missingCurrentWallpaper() async throws {
        var current = try wallpaper(id: 4, path: "2026-08-19/current.png", state: .available)
        current.isCurrent = true
        let store = try InMemoryRepositoryStore(wallpapers: [current])
        let report = try await MaintainWallpaperFilesUseCase(
            wallpapers: store,
            fileInventory: RecordingFileInventory(paths: []),
            logger: NoOpAppLogger()
        ).execute()

        let persisted = try #require(try await store.wallpaper(id: current.id))
        #expect(report.missingRecordIDs == [current.id])
        #expect(persisted.fileState == .missing)
        #expect(persisted.isCurrent)
    }

    @Test("A repaired file state survives reopening the disk store")
    func maintenancePersistsAcrossReopen() async throws {
        let rootURL = temporaryDirectory(name: "reopen")
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let storeURL = rootURL.appendingPathComponent("ZIKORA.store")
        let wallpaper = try wallpaper(id: 5, path: "2026-08-19/gone.png", state: .available)

        do {
            let container = try PersistenceContainerFactory.makeStore(at: storeURL)
            let store = SwiftDataRepositoryStore(modelContainer: container)
            try await store.save(wallpaper)
            _ = try await MaintainWallpaperFilesUseCase(
                wallpapers: store,
                fileInventory: RecordingFileInventory(paths: []),
                logger: NoOpAppLogger()
            ).execute()
            #expect(try await store.wallpaper(id: wallpaper.id)?.fileState == .missing)
        }

        let reopenedContainer = try PersistenceContainerFactory.makeStore(at: storeURL)
        let reopenedStore = SwiftDataRepositoryStore(modelContainer: reopenedContainer)
        #expect(try await reopenedStore.wallpaper(id: wallpaper.id)?.fileState == .missing)
    }

    @Test("Local inventory ignores symlinks that can leave the managed root")
    func localInventoryRejectsSymlinks() async throws {
        let rootURL = temporaryDirectory(name: "inventory")
        let outsideURL = temporaryDirectory(name: "outside")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
        let knownURL = rootURL.appendingPathComponent("known.png")
        let outsideFileURL = outsideURL.appendingPathComponent("private.png")
        #expect(FileManager.default.createFile(atPath: knownURL.path, contents: Data([1])))
        #expect(FileManager.default.createFile(atPath: outsideFileURL.path, contents: Data([2])))
        try FileManager.default.createSymbolicLink(
            at: rootURL.appendingPathComponent("escaped.png"),
            withDestinationURL: outsideFileURL
        )

        let paths = try await LocalManagedFileInventory(rootURL: rootURL).inventory()
        #expect(paths == [try #require(ManagedRelativePath(rawValue: "known.png"))])
        #expect(FileManager.default.fileExists(atPath: outsideFileURL.path))
    }

    private func wallpaper(
        id: UInt8,
        path: String,
        state: WallpaperFileState
    ) throws -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(id)),
            contentHash: "hash-\(id)",
            sourceID: nil,
            sourceNameSnapshot: "Fixture",
            relativePath: try #require(ManagedRelativePath(rawValue: path)),
            downloadDay: try #require(LocalDay(rawValue: "2026-08-19")),
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 4,
            format: .png,
            fileState: state,
            isCurrent: false
        )
    }

    private func temporaryDirectory(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "zikora-p02-06-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private actor RecordingFileInventory: ManagedFileInventoryProviding {
    private let paths: Set<ManagedRelativePath>
    private(set) var inventoryCallCount = 0

    init(paths: Set<ManagedRelativePath>) {
        self.paths = paths
    }

    func inventory() async throws -> Set<ManagedRelativePath> {
        inventoryCallCount += 1
        return paths
    }
}

private final class RecordingMaintenanceLogger: AppLogging, Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [AppLogRecord]())

    var records: [AppLogRecord] {
        storage.withLock { $0 }
    }

    func log(_ record: AppLogRecord) {
        storage.withLock { $0.append(record) }
    }
}
