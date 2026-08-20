import Foundation

nonisolated struct SourceConnectionPreview: Equatable, Sendable {
    let pixelWidth: Int
    let pixelHeight: Int
    let formatIdentifier: String
    let byteCount: Int64
    let responseMIMEType: String?
}

nonisolated struct SourceConnectionTestResult: Equatable, Sendable {
    let proof: SourceConnectionTestProof
    let preview: SourceConnectionPreview
}

/// Runs the network and image checks required before a source can be saved.
/// The downloader owns the temporary file contract; this use case removes it
/// after validation so a connection test never leaves an application asset.
nonisolated struct TestSourceConnectionUseCase: Sendable {
    private let downloader: any ImageDownloading
    private let validator: any ImageValidating
    private let clock: any Clock

    init(
        downloader: any ImageDownloading,
        validator: any ImageValidating,
        clock: any Clock = SystemClock()
    ) {
        self.downloader = downloader
        self.validator = validator
        self.clock = clock
    }

    func execute(input: SourceFormInput) async throws -> SourceConnectionTestResult {
        try Task.checkCancellation()

        guard let validatedInput = EvaluateSourceInputUseCase.validate(input).input else {
            throw AppFailure(code: .invalidURL, recoveryAction: .editSource)
        }

        let downloaded: DownloadedImage
        do {
            downloaded = try await downloader.download(from: validatedInput.url)
        } catch {
            throw Self.map(error)
        }

        defer {
            try? FileManager.default.removeItem(at: downloaded.temporaryFileURL)
        }

        try Task.checkCancellation()

        let validated: ValidatedImage
        do {
            validated = try await validator.validate(
                fileAt: downloaded.temporaryFileURL,
                declaredMIMEType: downloaded.responseMIMEType
            )
        } catch {
            throw Self.map(error)
        }

        try Task.checkCancellation()
        let testedAt = await clock.now()
        return SourceConnectionTestResult(
            proof: SourceConnectionTestProof(
                inputFingerprint: validatedInput.fingerprint,
                testedAt: testedAt
            ),
            preview: SourceConnectionPreview(
                pixelWidth: validated.pixelWidth,
                pixelHeight: validated.pixelHeight,
                formatIdentifier: validated.formatIdentifier,
                byteCount: downloaded.byteCount,
                responseMIMEType: downloaded.responseMIMEType
            )
        )
    }

    private static func map(_ error: Error) -> Error {
        if error is CancellationError {
            return error
        }
        if let failure = error as? AppFailure {
            return failure
        }
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
        return AppFailure(code: .invalidResponse)
    }
}

/// Serializes UI-triggered tests. Starting a new test cancels the previous
/// one, preventing a stale response from unlocking a changed form.
actor SourceConnectionTestCoordinator {
    private let useCase: TestSourceConnectionUseCase
    private var activeTask: Task<SourceConnectionTestResult, Error>?

    init(useCase: TestSourceConnectionUseCase) {
        self.useCase = useCase
    }

    func test(input: SourceFormInput) async throws -> SourceConnectionTestResult {
        activeTask?.cancel()
        let task = Task { try await useCase.execute(input: input) }
        activeTask = task
        defer { activeTask = nil }
        return try await task.value
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }
}
