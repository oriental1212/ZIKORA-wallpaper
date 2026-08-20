import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct TestSourceConnectionUseCaseTests {
    @Test("Connection test validates, downloads, decodes, and returns a matching preview proof")
    func runsPipeline() async throws {
        let temporaryURL = try makeTemporaryFile()
        let input = SourceFormInput(
            name: "  Daily  ",
            urlText: "HTTPS://EXAMPLE.TEST/image.png?token=secret",
            isEnabled: true
        )
        let downloader = StubImageDownloader(
            result: DownloadedImage(
                temporaryFileURL: temporaryURL,
                responseMIMEType: "image/png",
                byteCount: 1234
            )
        )
        let validator = StubImageValidator(
            result: ValidatedImage(
                pixelWidth: 1920,
                pixelHeight: 1080,
                formatIdentifier: "public.png"
            )
        )
        let useCase = TestSourceConnectionUseCase(
            downloader: downloader,
            validator: validator,
            clock: FixedClock(date: Date(timeIntervalSince1970: 42))
        )

        let result = try await useCase.execute(input: input)

        let validated = try #require(EvaluateSourceInputUseCase.validate(input).input)
        #expect(result.proof.inputFingerprint == validated.fingerprint)
        #expect(result.proof.testedAt == Date(timeIntervalSince1970: 42))
        #expect(result.preview == SourceConnectionPreview(
            pixelWidth: 1920,
            pixelHeight: 1080,
            formatIdentifier: "public.png",
            byteCount: 1234,
            responseMIMEType: "image/png"
        ))
        #expect(!FileManager.default.fileExists(atPath: temporaryURL.path))
    }

    @Test("Connection test maps timeout and does not request an invalid URL")
    func mapsFailures() async throws {
        let downloader = StubImageDownloader(error: URLError(.timedOut))
        let validator = StubImageValidator(result: ValidatedImage(
            pixelWidth: 1, pixelHeight: 1, formatIdentifier: "public.png"
        ))
        let useCase = TestSourceConnectionUseCase(downloader: downloader, validator: validator)

        await #expect(throws: AppFailure(code: .invalidURL)) {
            try await useCase.execute(input: SourceFormInput(
                name: "Image", urlText: "file:///tmp/image.png", isEnabled: true
            ))
        }
        #expect(await downloader.callCount == 0)

        await #expect(throws: AppFailure(code: .requestTimedOut)) {
            try await useCase.execute(input: SourceFormInput(
                name: "Image", urlText: "https://example.test/image.png", isEnabled: true
            ))
        }
    }

    @Test("A cancelled connection test cannot produce a result for the changed input")
    func cancellationDoesNotProduceStaleResult() async throws {
        let firstURL = try makeTemporaryFile()
        let secondURL = try makeTemporaryFile()
        let downloader = BlockingImageDownloader(files: [firstURL, secondURL])
        let validator = StubImageValidator(result: ValidatedImage(
            pixelWidth: 1, pixelHeight: 1, formatIdentifier: "public.png"
        ))
        let coordinator = SourceConnectionTestCoordinator(useCase: TestSourceConnectionUseCase(
            downloader: downloader,
            validator: validator,
            clock: FixedClock(date: Date(timeIntervalSince1970: 7))
        ))

        let first = Task {
            try await coordinator.test(input: SourceFormInput(
                name: "First", urlText: "https://example.test/first.png", isEnabled: true
            ))
        }
        await downloader.waitUntilStarted()
        let second = Task {
            try await coordinator.test(input: SourceFormInput(
                name: "Second", urlText: "https://example.test/second.png", isEnabled: true
            ))
        }
        await downloader.waitUntilStarted(count: 2)
        await downloader.releaseNext()

        await #expect(throws: CancellationError.self) { try await first.value }
        let result = try await second.value
        #expect(result.proof.inputFingerprint.name == "Second")
    }

    private func makeTemporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zikora-connection-\(UUID().uuidString)")
        try Data("fixture".utf8).write(to: url)
        return url
    }
}

private actor StubImageDownloader: ImageDownloading {
    let result: DownloadedImage?
    let error: Error?
    private(set) var callCount = 0

    init(result: DownloadedImage) { self.result = result; self.error = nil }
    init(error: Error) { self.result = nil; self.error = error }

    func download(from _: URL) async throws -> DownloadedImage {
        callCount += 1
        if let error { throw error }
        return result!
    }
}

private struct StubImageValidator: ImageValidating {
    let result: ValidatedImage

    func validate(fileAt _: URL, declaredMIMEType _: String?) async throws -> ValidatedImage {
        result
    }
}

private actor BlockingImageDownloader: ImageDownloading {
    private var files: [URL]
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    init(files: [URL]) { self.files = files }

    func download(from _: URL) async throws -> DownloadedImage {
        startedCount += 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiters.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelWaiter() }
        }
        try Task.checkCancellation()
        return DownloadedImage(
            temporaryFileURL: files.removeFirst(),
            responseMIMEType: "image/png",
            byteCount: 1
        )
    }

    func waitUntilStarted(count: Int = 1) async {
        while startedCount < count { await Task.yield() }
    }

    func releaseNext() {
        waiters.removeFirst().resume()
    }

    private func cancelWaiter() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().resume()
    }
}
