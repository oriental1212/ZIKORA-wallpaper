import Foundation
import ImageIO
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct ThumbnailPipelineTests {
    @Test("Thumbnail generation decodes asynchronously and caches by content and target size")
    func generatesAndCachesThumbnail() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixtureURL(named: "valid-small.png")
        let renderer = CountingThumbnailRenderer(bytes: try Data(contentsOf: source))
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)
        let request = ThumbnailRequest(
            sourceURL: source,
            contentHash: String(repeating: "a", count: 64),
            size: ThumbnailSize(width: 120, height: 80)
        )

        let first = try await pipeline.thumbnail(for: request)
        let second = try await pipeline.thumbnail(for: request)

        #expect(first == second)
        #expect(await renderer.renderCount == 1)
        #expect(try #require(CGImageSourceCreateWithURL(first as CFURL, nil)) != nil)
        #expect(first.path.contains("Thumbnails"))
    }

    @Test("Concurrent requests for one key share one rendering task")
    func mergesConcurrentRequests() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixtureURL(named: "valid-small.png")
        let renderer = CountingThumbnailRenderer(bytes: try Data(contentsOf: source))
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)
        let request = ThumbnailRequest(
            sourceURL: source,
            contentHash: "same-content",
            size: ThumbnailSize(width: 64, height: 64)
        )

        let results = try await withThrowingTaskGroup(of: URL.self) { group in
            for _ in 0..<20 {
                group.addTask { try await pipeline.thumbnail(for: request) }
            }
            var values: [URL] = []
            for try await value in group { values.append(value) }
            return values
        }

        #expect(Set(results).count == 1)
        #expect(await renderer.renderCount == 1)
    }

    @Test("Cancellation does not leave an in-flight task or partial cache")
    func cancellationCleansInFlightRequest() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixtureURL(named: "valid-small.png")
        let renderer = CountingThumbnailRenderer(bytes: try Data(contentsOf: source))
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)
        let request = ThumbnailRequest(
            sourceURL: source,
            contentHash: "cancelled-content",
            size: ThumbnailSize(width: 64, height: 64)
        )

        let task = Task { try await pipeline.thumbnail(for: request) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await pipeline.activeRequestCount == 0)
        #expect(await renderer.renderCount == 0)
    }

    @Test("Missing and corrupt originals produce an unavailable result")
    func rejectsMissingAndCorruptOriginals() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let renderer = ImageIOThumbnailRenderer()
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)
        let missing = root.appendingPathComponent("missing.png")
        let corrupt = try fixtureURL(named: "corrupt-image.png")

        await #expect(throws: AppFailure(code: .fileOperationFailed)) {
            try await pipeline.thumbnail(for: ThumbnailRequest(
                sourceURL: missing,
                contentHash: "missing",
                size: ThumbnailSize(width: 64, height: 64)
            ))
        }
        await #expect(throws: AppFailure(code: .unsupportedImage)) {
            try await pipeline.thumbnail(for: ThumbnailRequest(
                sourceURL: corrupt,
                contentHash: "corrupt",
                size: ThumbnailSize(width: 64, height: 64)
            ))
        }
    }

    @Test("Content changes invalidate the old thumbnail cache")
    func invalidatesByContentHash() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixtureURL(named: "valid-small.png")
        let renderer = CountingThumbnailRenderer(bytes: try Data(contentsOf: source))
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)
        let hash = "content-to-invalidate"
        let request = ThumbnailRequest(
            sourceURL: source,
            contentHash: hash,
            size: ThumbnailSize(width: 32, height: 32)
        )

        _ = try await pipeline.thumbnail(for: request)
        await pipeline.invalidate(contentHash: hash)
        _ = try await pipeline.thumbnail(for: request)
        #expect(await renderer.renderCount == 2)
    }

    @Test("One thousand thumbnail records do not remain in-flight")
    func handlesLargeLibraryWithoutRetainingTasks() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixtureURL(named: "valid-small.png")
        let renderer = CountingThumbnailRenderer(bytes: try Data(contentsOf: source))
        let pipeline = try ThumbnailPipeline(rootURL: root, renderer: renderer)

        for index in 0..<1_000 {
            _ = try await pipeline.thumbnail(for: ThumbnailRequest(
                sourceURL: source,
                contentHash: "library-item-\(index)",
                size: ThumbnailSize(width: 48, height: 48)
            ))
        }
        #expect(await pipeline.activeRequestCount == 0)
        #expect(await renderer.renderCount == 1_000)
    }

    private func fixtureURL(named fileName: String) throws -> URL {
        let fileURL = URL(fileURLWithPath: fileName)
        return try #require(Bundle(for: FixtureBundleToken.self).url(
            forResource: fileURL.deletingPathExtension().lastPathComponent,
            withExtension: fileURL.pathExtension
        ))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("thumbnail-pipeline-\(UUID().uuidString)")
    }
}

private actor CountingThumbnailRenderer: ThumbnailRendering {
    let bytes: Data
    private(set) var renderCount = 0

    init(bytes: Data) { self.bytes = bytes }

    func render(sourceURL _: URL, destinationURL: URL, maxPixelSize _: Int) async throws {
        try Task.checkCancellation()
        renderCount += 1
        try bytes.write(to: destinationURL, options: .atomic)
    }
}

private final class FixtureBundleToken {}
