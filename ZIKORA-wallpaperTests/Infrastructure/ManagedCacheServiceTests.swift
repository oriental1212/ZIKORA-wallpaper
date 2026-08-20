import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct ManagedCacheServiceTests {
    @Test("Statistics are cached briefly and invalidation forces a refresh")
    func cachesAndInvalidatesStatistics() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileStore = CountingCacheFileStore(statisticsValue: FileStoreStatistics(fileCount: 2, byteCount: 90))
        let service = try ManagedCacheService(
            rootURL: root,
            fileStore: fileStore,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_787_000_000)),
            refreshInterval: 60
        )

        #expect(try await service.statistics() == FileStoreStatistics(fileCount: 2, byteCount: 90))
        #expect(try await service.statistics() == FileStoreStatistics(fileCount: 2, byteCount: 90))
        #expect(await fileStore.statisticsCallCount == 1)
        await service.invalidateStatistics()
        _ = try await service.statistics()
        #expect(await fileStore.statisticsCallCount == 2)
    }

    @Test("Statistics failures do not poison later refreshes")
    func retriesAfterStatisticsFailure() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileStore = CountingCacheFileStore(
            statisticsValue: FileStoreStatistics(fileCount: 1, byteCount: 10),
            failuresRemaining: 1
        )
        let service = try ManagedCacheService(rootURL: root, fileStore: fileStore)

        await #expect(throws: AppFailure(code: .fileOperationFailed)) {
            try await service.statistics()
        }
        #expect(try await service.statistics() == FileStoreStatistics(fileCount: 1, byteCount: 10))
        #expect(await fileStore.statisticsCallCount == 2)
    }

    @Test("Location returns a valid directory URL and does not invent a cache path")
    func exposesFinderLocation() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = try ManagedCacheService(
            rootURL: root,
            fileStore: CountingCacheFileStore(statisticsValue: .init(fileCount: 0, byteCount: 0))
        )

        let location = try await service.location()
        #expect(location.directoryURL.isFileURL)
        #expect(location.directoryURL.standardizedFileURL == root.standardizedFileURL)
        #expect(location.displayPath == root.standardizedFileURL.path)
        #expect(!location.displayPath.contains("~/.zikora/cache"))
    }

    @Test("A missing or regular-file location is rejected")
    func rejectsInvalidLocation() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-location-\(UUID().uuidString)")
        try Data("not-a-directory".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: AppFailure(code: .storageUnavailable)) {
            _ = try ManagedCacheService(
                rootURL: fileURL,
                fileStore: CountingCacheFileStore(statisticsValue: .init(fileCount: 0, byteCount: 0))
            )
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-service-\(UUID().uuidString)")
    }
}

private actor CountingCacheFileStore: WallpaperFileStore {
    let statisticsValue: FileStoreStatistics
    var failuresRemaining: Int
    private(set) var statisticsCallCount = 0

    init(statisticsValue: FileStoreStatistics, failuresRemaining: Int = 0) {
        self.statisticsValue = statisticsValue
        self.failuresRemaining = failuresRemaining
    }

    func commitTemporaryFile(at _: URL, preferredExtension _: String) async throws -> String {
        throw AppFailure(code: .fileOperationFailed)
    }

    func remove(relativePath _: String) async throws {
        throw AppFailure(code: .fileOperationFailed)
    }

    func statistics() async throws -> FileStoreStatistics {
        statisticsCallCount += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw AppFailure(code: .fileOperationFailed)
        }
        return statisticsValue
    }
}
