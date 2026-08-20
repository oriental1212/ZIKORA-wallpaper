import CryptoKit
import CoreGraphics
import Foundation
import ImageIO

actor ThumbnailPipeline: ThumbnailProviding {
    private struct CacheKey: Hashable, Sendable {
        let contentKey: String
        let size: ThumbnailSize
    }

    private let cacheRootURL: URL
    private let renderer: any ThumbnailRendering
    private let fileManager: FileManager
    private struct InFlight: Sendable {
        let id: UUID
        let task: Task<URL, Error>
        var waiterCount: Int
    }
    private var inFlight: [CacheKey: InFlight] = [:]

    init(
        rootURL: URL,
        renderer: any ThumbnailRendering = ImageIOThumbnailRenderer(),
        fileManager: FileManager = .default
    ) throws {
        self.cacheRootURL = rootURL
            .standardizedFileURL
            .appendingPathComponent("Thumbnails", isDirectory: true)
        self.renderer = renderer
        self.fileManager = fileManager
        do {
            try fileManager.createDirectory(
                at: self.cacheRootURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw AppFailure(code: .storageUnavailable)
        }
    }

    func thumbnail(for request: ThumbnailRequest) async throws -> URL {
        try Task.checkCancellation()
        try validateSource(request.sourceURL)
        let key = CacheKey(
            contentKey: Self.contentKey(for: request.contentHash),
            size: request.size
        )
        let cacheURL = cacheURL(for: key)
        if Self.isValidImage(at: cacheURL) {
            return cacheURL
        }
        cleanup(url: cacheURL)

        let task: Task<URL, Error>
        let inFlightID: UUID
        if let existing = inFlight[key] {
            task = existing.task
            inFlightID = existing.id
            inFlight[key]?.waiterCount += 1
        } else {
            let sourceURL = request.sourceURL
            let renderer = self.renderer
            let cacheRootURL = self.cacheRootURL
            let destinationURL = cacheURL
            task = Task {
                let stagingURL = cacheRootURL.appendingPathComponent(
                    ".\(destinationURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).partial"
                )
                defer { try? FileManager.default.removeItem(at: stagingURL) }
                try Task.checkCancellation()
                try await renderer.render(
                    sourceURL: sourceURL,
                    destinationURL: stagingURL,
                    maxPixelSize: key.size.maxPixelSize
                )
                try Task.checkCancellation()
                guard Self.isValidImage(at: stagingURL) else {
                    throw AppFailure(code: .unsupportedImage, recoveryAction: .editSource)
                }
                try FileManager.default.moveItem(at: stagingURL, to: destinationURL)
                return destinationURL
            }
            inFlightID = UUID()
            inFlight[key] = InFlight(id: inFlightID, task: task, waiterCount: 1)
        }

        return try await withTaskCancellationHandler {
            do {
                let result = try await task.value
                release(key: key, id: inFlightID)
                return result
            } catch {
                release(key: key, id: inFlightID)
                throw error
            }
        } onCancel: {
            Task { await self.cancel(key: key) }
        }
    }

    func invalidate(contentHash: String) async {
        let prefix = Self.contentKey(for: contentHash) + "-"
        guard let enumerator = fileManager.enumerator(
            at: cacheRootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants]
        ) else { return }
        for case let url as URL in enumerator.allObjects {
            if url.deletingPathExtension().lastPathComponent.hasPrefix(prefix) {
                cleanup(url: url)
            }
        }
    }

    var activeRequestCount: Int {
        inFlight.count
    }

    private func cancel(key: CacheKey) {
        inFlight[key]?.task.cancel()
        inFlight[key] = nil
    }

    private func release(key: CacheKey, id: UUID) {
        guard var entry = inFlight[key], entry.id == id else { return }
        entry.waiterCount -= 1
        inFlight[key] = entry.waiterCount > 0 ? entry : nil
    }

    private func cacheURL(for key: CacheKey) -> URL {
        cacheRootURL.appendingPathComponent(
            "\(key.contentKey)-\(key.size.width)x\(key.size.height).png"
        )
    }

    private func validateSource(_ url: URL) throws {
        guard url.isFileURL,
              fileManager.fileExists(atPath: url.path) else {
            throw AppFailure(code: .fileOperationFailed)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw AppFailure(code: .fileOperationFailed)
        }
    }

    private func cleanup(url: URL) {
        try? fileManager.removeItem(at: url)
    }

    private static func contentKey(for contentHash: String) -> String {
        SHA256.hash(data: Data(contentHash.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isValidImage(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return false
        }
        return image.width > 0 && image.height > 0
    }
}
