import Foundation

/// A bounded, file-backed image downloader. The delegate receives response
/// chunks incrementally so a remote response is never assembled in memory.
// The downloader stores only immutable configuration and logger references;
// each request creates its own delegate/session pair.
final class URLSessionImageDownloader: NSObject, ImageDownloading, @unchecked Sendable {
    static let maximumBytes: Int64 = 50 * 1024 * 1024
    static let maximumRedirects = 5
    static let requestTimeout: TimeInterval = 15

    private let logger: any AppLogging
    private let sessionConfiguration: URLSessionConfiguration
    private let maximumBytes: Int64
    private let maximumRedirects: Int
    private let requestTimeout: TimeInterval

    init(
        logger: any AppLogging = NoOpAppLogger(),
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        maximumBytes: Int64 = URLSessionImageDownloader.maximumBytes,
        maximumRedirects: Int = URLSessionImageDownloader.maximumRedirects,
        requestTimeout: TimeInterval = URLSessionImageDownloader.requestTimeout
    ) {
        self.logger = logger
        self.sessionConfiguration = sessionConfiguration
        self.maximumBytes = maximumBytes
        self.maximumRedirects = maximumRedirects
        self.requestTimeout = requestTimeout
    }

    func download(from url: URL) async throws -> DownloadedImage {
        guard Self.isSupportedURL(url) else {
            throw AppFailure(code: .invalidURL, recoveryAction: .editSource)
        }

        try Task.checkCancellation()
        logger.log(AppLogRecord(
            category: .networking,
            level: .information,
            event: .requestStarted,
            url: url
        ))

        let configuration = sessionConfiguration.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil

        let delegate = ImageDownloadDelegate(
            sourceURL: url,
            maximumBytes: maximumBytes,
            maximumRedirects: maximumRedirects,
            logger: logger
        )
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                delegate.start(
                    request: URLRequest(url: url, timeoutInterval: requestTimeout),
                    session: session,
                    continuation: continuation
                )
            }
        }, onCancel: {
            delegate.cancel()
        })
    }

    private static func isSupportedURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return false
        }
        return true
    }
}

// URLSession callbacks and task cancellation may arrive on different queues;
// every mutable field below is protected by `lock`.
private final class ImageDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let sourceURL: URL
    private let maximumBytes: Int64
    private let maximumRedirects: Int
    private let logger: any AppLogging
    private let lock = NSLock()

    private var continuation: CheckedContinuation<DownloadedImage, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var temporaryFileURL: URL?
    private var responseMIMEType: String?
    private var byteCount: Int64 = 0
    private var redirectCount = 0
    private var finished = false

    init(
        sourceURL: URL,
        maximumBytes: Int64,
        maximumRedirects: Int,
        logger: any AppLogging
    ) {
        self.sourceURL = sourceURL
        self.maximumBytes = maximumBytes
        self.maximumRedirects = maximumRedirects
        self.logger = logger
    }

    func start(
        request: URLRequest,
        session: URLSession,
        continuation: CheckedContinuation<DownloadedImage, Error>
    ) {
        lock.lock()
        self.session = session
        self.continuation = continuation
        let task = session.dataTask(with: request)
        self.task = task
        lock.unlock()
        task.resume()
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        redirectCount += 1
        let count = redirectCount
        lock.unlock()

        guard count <= maximumRedirects else {
            completionHandler(nil)
            finish(.failure(AppFailure(code: .invalidResponse)))
            return
        }
        completionHandler(request)
        _ = response
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(AppFailure(code: .invalidResponse)))
            return
        }

        let expectedLength = response.expectedContentLength
        if expectedLength > maximumBytes {
            completionHandler(.cancel)
            finish(.failure(AppFailure(code: .imageTooLarge)))
            return
        }

        do {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("zikora-download-\(UUID().uuidString)", isDirectory: false)
            guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                throw AppFailure(code: .storageUnavailable)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            lock.lock()
            temporaryFileURL = fileURL
            fileHandle = handle
            responseMIMEType = httpResponse.mimeType
            lock.unlock()
            completionHandler(.allow)
        } catch {
            completionHandler(.cancel)
            finish(.failure(Self.map(error)))
        }
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !finished, let handle = fileHandle else {
            lock.unlock()
            return
        }
        let nextCount = byteCount.addingReportingOverflow(Int64(data.count))
        guard !nextCount.overflow, nextCount.partialValue <= maximumBytes else {
            lock.unlock()
            finish(.failure(AppFailure(code: .imageTooLarge)))
            return
        }
        byteCount = nextCount.partialValue
        do {
            try handle.write(contentsOf: data)
            lock.unlock()
        } catch {
            lock.unlock()
            finish(.failure(Self.map(error)))
        }
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(Self.map(error)))
            return
        }

        lock.lock()
        let result = temporaryFileURL.flatMap { fileURL in
            DownloadedImage(
                temporaryFileURL: fileURL,
                responseMIMEType: responseMIMEType,
                byteCount: byteCount
            )
        }
        lock.unlock()

        guard let result else {
            finish(.failure(AppFailure(code: .invalidResponse)))
            return
        }
        finish(.success(result), removeTemporaryFile: false)
    }

    private func finish(
        _ result: Result<DownloadedImage, Error>,
        removeTemporaryFile: Bool = true
    ) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        let session = self.session
        let task = self.task
        let handle = self.fileHandle
        let fileURL = self.temporaryFileURL
        self.continuation = nil
        self.fileHandle = nil
        lock.unlock()

        try? handle?.close()
        if removeTemporaryFile, let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        task?.cancel()
        session?.invalidateAndCancel()

        if case .failure(let error) = result {
            let failure = (error as? AppFailure) ?? AppFailure(code: .unknown)
            logger.log(AppLogRecord(
                category: .networking,
                level: .warning,
                event: .operationFailed,
                errorCode: failure.code,
                url: sourceURL
            ))
        }
        continuation?.resume(with: result)
    }

    private static func map(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if let failure = error as? AppFailure { return failure }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return AppFailure(code: .requestTimedOut)
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed:
                return AppFailure(code: .networkUnavailable)
            default:
                return AppFailure(code: .invalidResponse)
            }
        }
        return AppFailure(code: .fileOperationFailed)
    }
}
