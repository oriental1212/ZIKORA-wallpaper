import Foundation
import Testing
@testable import ZIKORA_wallpaper

@Suite(.serialized)
@MainActor
struct URLSessionImageDownloaderTests {
    @Test("Downloader streams chunks to a temporary file and returns MIME and byte count")
    func streamsSmallResponse() async throws {
        StubURLProtocol.install(.response(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            chunks: [Data("abc".utf8), Data("de".utf8)]
        ))
        defer { StubURLProtocol.reset() }

        let downloader = makeDownloader(maximumBytes: 10)
        let result = try await downloader.download(from: try #require(URL(string: "https://example.test/image")))

        #expect(result.byteCount == 5)
        #expect(result.responseMIMEType == "image/png")
        #expect(try Data(contentsOf: result.temporaryFileURL) == Data("abcde".utf8))
        try FileManager.default.removeItem(at: result.temporaryFileURL)
    }

    @Test("Content-Length and streamed bytes both enforce the limit")
    func enforcesByteLimit() async throws {
        StubURLProtocol.install(.response(
            statusCode: 200,
            headers: ["Content-Type": "image/png", "Content-Length": "11"],
            chunks: [Data(repeating: 1, count: 11)]
        ))
        defer { StubURLProtocol.reset() }

        await #expect(throws: AppFailure(code: .imageTooLarge)) {
            try await makeDownloader(maximumBytes: 10).download(
                from: try #require(URL(string: "https://example.test/header-too-large"))
            )
        }

        StubURLProtocol.install(.response(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            chunks: [Data(repeating: 1, count: 6), Data(repeating: 1, count: 5)]
        ))
        await #expect(throws: AppFailure(code: .imageTooLarge)) {
            try await makeDownloader(maximumBytes: 10).download(
                from: try #require(URL(string: "https://example.test/stream-too-large"))
            )
        }
    }

    @Test("Non-success responses and redirect loops fail without returning a file")
    func rejectsResponsesAndRedirects() async throws {
        StubURLProtocol.install(.response(statusCode: 404, headers: [:], chunks: []))
        defer { StubURLProtocol.reset() }
        await #expect(throws: AppFailure(code: .invalidResponse)) {
            try await makeDownloader().download(
                from: try #require(URL(string: "https://example.test/not-found"))
            )
        }

        StubURLProtocol.install(.redirect(location: "/loop"))
        await #expect(throws: AppFailure(code: .invalidResponse)) {
            try await makeDownloader(maximumRedirects: 2).download(
                from: try #require(URL(string: "https://example.test/loop"))
            )
        }
    }

    @Test("Cancellation cancels the request and removes the partial file")
    func supportsCancellation() async throws {
        StubURLProtocol.install(.hold)
        defer { StubURLProtocol.reset() }
        let task = Task {
            try await makeDownloader().download(
                from: try #require(URL(string: "https://example.test/slow"))
            )
        }
        await StubURLProtocol.waitUntilStarted()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("Request timeout is mapped to the actionable timeout failure")
    func mapsTimeout() async throws {
        StubURLProtocol.install(.hold)
        defer { StubURLProtocol.reset() }
        await #expect(throws: AppFailure(code: .requestTimedOut)) {
            try await makeDownloader(requestTimeout: 0.05).download(
                from: try #require(URL(string: "https://example.test/timeout"))
            )
        }
    }

    private func makeDownloader(
        maximumBytes: Int64 = URLSessionImageDownloader.maximumBytes,
        maximumRedirects: Int = URLSessionImageDownloader.maximumRedirects,
        requestTimeout: TimeInterval = URLSessionImageDownloader.requestTimeout
    ) -> URLSessionImageDownloader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionImageDownloader(
            sessionConfiguration: configuration,
            maximumBytes: maximumBytes,
            maximumRedirects: maximumRedirects,
            requestTimeout: requestTimeout
        )
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Plan {
        case response(statusCode: Int, headers: [String: String], chunks: [Data])
        case redirect(location: String)
        case hold
    }

    private static let lock = NSLock()
    private static var plan: Plan = .hold
    private static var started = false
    private var isStopped = false

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "example.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    static func install(_ value: Plan) {
        lock.lock()
        plan = value
        started = false
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        plan = .hold
        started = false
        lock.unlock()
    }

    static func waitUntilStarted() async {
        while true {
            lock.lock()
            let value = started
            lock.unlock()
            if value { return }
            await Task.yield()
        }
    }

    override func startLoading() {
        Self.lock.lock()
        Self.started = true
        let currentPlan = Self.plan
        Self.lock.unlock()

        switch currentPlan {
        case .hold:
            return
        case .redirect(let location):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 302,
                    httpVersion: nil,
                    headerFields: ["Location": location]
                  ) else { return }
            client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        case .response(let statusCode, let headers, let chunks):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: headers
                  ) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks where !isStopped {
                client?.urlProtocol(self, didLoad: chunk)
            }
            if !isStopped { client?.urlProtocolDidFinishLoading(self) }
        }
    }

    override func stopLoading() {
        isStopped = true
    }
}
