import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct AtomicWallpaperFileStoreTests {
    @Test("Validated temporary files are staged and atomically committed under a logical day")
    func commitsToManagedDayDirectory() async throws {
        let root = temporaryDirectory(name: "commit")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try temporaryFile(contents: Data("complete-image".utf8))
        defer { try? FileManager.default.removeItem(at: source) }
        let store = try makeStore(root: root, uuid: 1)

        let relativePath = try await store.commitTemporaryFile(at: source, preferredExtension: "PNG")
        let destination = root.appendingPathComponent(relativePath)

        #expect(relativePath == "2026-08-18/00000000-0000-0000-0000-000000000001.png")
        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: destination) == Data("complete-image".utf8))
        #expect(!FileManager.default.fileExists(
            atPath: destination.deletingLastPathComponent()
                .appendingPathComponent(".00000000-0000-0000-0000-000000000001.partial").path
        ))
    }

    @Test("Invalid extension and failed commit remove the temporary source")
    func failedCommitCleansTemporaryFile() async throws {
        let root = temporaryDirectory(name: "failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try temporaryFile(contents: Data("not-committed".utf8))
        let store = try makeStore(root: root, uuid: 2)

        await #expect(throws: AppFailure(code: .fileOperationFailed)) {
            try await store.commitTemporaryFile(at: source, preferredExtension: "png/escape")
        }
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(try await store.statistics() == FileStoreStatistics(fileCount: 0, byteCount: 0))
    }

    @Test("Name collisions do not overwrite an existing file")
    func collisionPreservesExistingFile() async throws {
        let root = temporaryDirectory(name: "collision")
        defer { try? FileManager.default.removeItem(at: root) }
        let firstSource = try temporaryFile(contents: Data("first".utf8))
        let secondSource = try temporaryFile(contents: Data("second".utf8))
        let store = try makeStore(root: root, uuid: 3)
        let firstPath = try await store.commitTemporaryFile(at: firstSource, preferredExtension: "jpg")

        await #expect(throws: AppFailure(code: .storageUnavailable)) {
            try await store.commitTemporaryFile(at: secondSource, preferredExtension: "jpg")
        }
        #expect(try Data(contentsOf: root.appendingPathComponent(firstPath)) == Data("first".utf8))
        #expect(!FileManager.default.fileExists(atPath: secondSource.path))
    }

    @Test("Remove and statistics remain confined to the managed root")
    func removesSafelyAndReportsStatistics() async throws {
        let root = temporaryDirectory(name: "statistics")
        let outside = temporaryDirectory(name: "outside")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let source = try temporaryFile(contents: Data(repeating: 7, count: 9))
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let store = try makeStore(root: root, uuid: 4)
        let relativePath = try await store.commitTemporaryFile(at: source, preferredExtension: "webp")

        #expect(try await store.statistics() == FileStoreStatistics(fileCount: 1, byteCount: 9))
        await #expect(throws: AppFailure(code: .fileOperationFailed)) {
            try await store.remove(relativePath: "../outside.txt")
        }
        try await store.remove(relativePath: relativePath)
        #expect(try await store.statistics() == FileStoreStatistics(fileCount: 0, byteCount: 0))
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test("A root that is a regular file is rejected")
    func rejectsNonDirectoryRoot() throws {
        let fileURL = temporaryFileURL()
        try Data("root".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: AppFailure(code: .storageUnavailable)) {
            _ = try AtomicWallpaperFileStore(rootURL: fileURL)
        }
    }

    private func makeStore(root: URL, uuid: UInt8) throws -> AtomicWallpaperFileStore {
        try AtomicWallpaperFileStore(
            rootURL: root,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_787_000_000)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai")),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(uuid))
        )
    }

    private func temporaryFile(contents: Data) throws -> URL {
        let url = temporaryFileURL()
        try contents.write(to: url, options: .atomic)
        return url
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atomic-store-\(UUID().uuidString).tmp")
    }

    private func temporaryDirectory(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atomic-store-\(name)-\(UUID().uuidString)")
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
