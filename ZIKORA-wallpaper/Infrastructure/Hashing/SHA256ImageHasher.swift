import CryptoKit
import Foundation

/// Computes a stable content identity without loading the complete image into memory.
struct SHA256ImageHasher: ImageContentHashing, Sendable {
    private let chunkSize: Int

    init(chunkSize: Int = 1024 * 1024) {
        self.chunkSize = max(1, chunkSize)
    }

    func hash(fileAt url: URL) async throws -> ContentHash {
        guard url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            throw AppFailure(code: .fileOperationFailed)
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw AppFailure(code: .fileOperationFailed)
        }
        defer { try? handle.close() }

        var digest = SHA256()
        var byteCount: Int64 = 0
        do {
            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                try Task.checkCancellation()
                digest.update(data: chunk)
                byteCount += Int64(chunk.count)
            }
        } catch is CancellationError {
            throw AppFailure(code: .operationCancelled)
        } catch {
            throw AppFailure(code: .fileOperationFailed)
        }

        let hex = digest.finalize().map { String(format: "%02x", $0) }.joined()
        return ContentHash(value: hex, byteCount: byteCount)
    }
}
