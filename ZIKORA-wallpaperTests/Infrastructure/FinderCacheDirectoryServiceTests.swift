import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct FinderCacheDirectoryServiceTests {
    @Test("Finder directory service safely creates and opens the managed root")
    func opensRoot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p06-finder-\(UUID().uuidString)", isDirectory: true)
        let opener = RecordingURLOpener()
        let service = FinderCacheDirectoryService(rootURL: root, opener: opener)

        #expect(try await service.openDirectory() == root.standardizedFileURL)
        #expect(await opener.urls() == [root.standardizedFileURL])
        #expect(FileManager.default.fileExists(atPath: root.path))
        try? FileManager.default.removeItem(at: root)
    }

    @Test("Finder reveal rejects path escape and reports missing file")
    func rejectsEscapeAndMissing() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p06-finder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = FinderCacheDirectoryService(rootURL: root, opener: RecordingURLOpener())

        await #expect(throws: FinderDirectoryError.fileMissing) {
            try await service.reveal(relativePath: ManagedRelativePath(rawValue: "missing.jpg")!)
        }
        #expect(FinderCacheDirectoryService.isInside(
            url: root.deletingLastPathComponent(), root: root
        ) == false)
    }

    @Test("Finder reveal opens only an existing managed file")
    func opensExistingFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p06-finder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("wallpaper.jpg")
        try Data([1, 2, 3]).write(to: file)
        let opener = RecordingURLOpener()
        let service = FinderCacheDirectoryService(rootURL: root, opener: opener)

        #expect(try await service.reveal(relativePath: ManagedRelativePath(rawValue: "wallpaper.jpg")!) == file)
        #expect(await opener.urls() == [file.standardizedFileURL])
    }
}

private actor RecordingURLOpener: URLOpening {
    private var opened: [URL] = []
    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return true
    }
    func urls() -> [URL] { opened }
}
