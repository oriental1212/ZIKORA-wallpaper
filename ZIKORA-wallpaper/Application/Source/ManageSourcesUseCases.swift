import Foundation

nonisolated struct ListSourcesUseCase: Sendable {
    private let sources: any SourceRepository

    init(sources: any SourceRepository) {
        self.sources = sources
    }

    func execute() async throws -> [WallpaperSource] {
        try await sources.allSources()
    }
}

nonisolated struct SaveSourceUseCase: Sendable {
    private let sources: any SourceRepository
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerating

    init(
        sources: any SourceRepository,
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.sources = sources
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    func execute(
        input: SourceFormInput,
        context: SourceInputContext,
        connectionProof: SourceConnectionTestProof?,
        duplicateURLConfirmation: SourceDuplicateURLConfirmation? = nil
    ) async throws -> WallpaperSource {
        let decision = try await EvaluateSourceInputUseCase(sources: sources).execute(
            input: input,
            context: context,
            connectionProof: connectionProof,
            duplicateURLConfirmation: duplicateURLConfirmation
        )
        guard decision.canSave, let input = decision.validatedInput else {
            throw SourceManagementError.inputNotReady
        }

        let now = await clock.now()
        let source: WallpaperSource
        switch context {
        case .create:
            source = WallpaperSource(
                id: SourceID(rawValue: await uuidGenerator.makeUUID()),
                name: input.name,
                url: input.url,
                isEnabled: input.isEnabled,
                createdAt: now,
                updatedAt: now,
                lastFetchAt: nil,
                lastFetchStatus: .never,
                lastErrorCode: nil,
                lastErrorMessage: nil,
                consecutiveFailureDays: 0
            )
        case .edit(let sourceID, let originalURL):
            guard var existing = try await sources.source(id: sourceID) else {
                throw RepositoryError.notFound(entity: .source)
            }
            guard existing.url == originalURL else {
                throw SourceManagementError.inputNotReady
            }
            existing.name = input.name
            existing.url = input.url
            existing.isEnabled = input.isEnabled
            existing.updatedAt = now
            source = existing
        }

        try await sources.save(source)
        return source
    }
}

nonisolated struct SetSourceEnabledUseCase: Sendable {
    private let sources: any SourceRepository
    private let clock: any Clock

    init(
        sources: any SourceRepository,
        clock: any Clock = SystemClock()
    ) {
        self.sources = sources
        self.clock = clock
    }

    func execute(sourceID: SourceID, isEnabled: Bool) async throws -> WallpaperSource {
        guard var source = try await sources.source(id: sourceID) else {
            throw RepositoryError.notFound(entity: .source)
        }
        guard source.isEnabled != isEnabled else {
            return source
        }

        source.isEnabled = isEnabled
        source.updatedAt = await clock.now()
        try await sources.save(source)
        return source
    }
}

nonisolated struct DeleteSourceUseCase: Sendable {
    private let repository: any RepositoryStore
    private let clock: any Clock

    init(
        repository: any RepositoryStore,
        clock: any Clock = SystemClock()
    ) {
        self.repository = repository
        self.clock = clock
    }

    func preview(sourceID: SourceID) async throws -> SourceDeletionImpact {
        guard let source = try await repository.source(id: sourceID) else {
            throw RepositoryError.notFound(entity: .source)
        }
        let schedule = try await repository.loadSchedule()
        return SourceDeletionImpact(
            sourceID: sourceID,
            sourceName: source.name,
            affectedWeekdays: Weekday.allCases.filter {
                schedule?.sourceID(for: $0) == sourceID
            },
            wasDefaultSource: schedule?.defaultSourceID == sourceID
        )
    }

    func execute(sourceID: SourceID) async throws -> SourceDeletionImpact {
        try await repository.delete(
            id: sourceID,
            scheduleUpdatedAt: await clock.now()
        )
    }
}

nonisolated struct UpdateSourceHealthUseCase: Sendable {
    private let sources: any SourceRepository

    init(sources: any SourceRepository) {
        self.sources = sources
    }

    func execute(sourceID: SourceID, event: SourceHealthEvent) async throws -> WallpaperSource {
        guard var source = try await sources.source(id: sourceID) else {
            throw RepositoryError.notFound(entity: .source)
        }

        switch event {
        case .requestStarted(let date):
            source.lastFetchAt = date
            source.lastFetchStatus = .loading
            source.updatedAt = date
        case .requestFailed(let date, let status, let errorCode, let message):
            try Self.requireFailureStatus(status)
            source.lastFetchAt = date
            source.lastFetchStatus = status
            source.lastErrorCode = errorCode
            source.lastErrorMessage = message
            source.updatedAt = date
        case .dailyFailureSettled(let date, let status, let errorCode, let message):
            try Self.requireFailureStatus(status)
            source.lastFetchAt = date
            source.lastFetchStatus = status
            source.lastErrorCode = errorCode
            source.lastErrorMessage = message
            if source.consecutiveFailureDays < Int.max {
                source.consecutiveFailureDays += 1
            }
            source.updatedAt = date
        case .requestSucceeded(let date):
            source.lastFetchAt = date
            source.lastFetchStatus = .success
            source.lastErrorCode = nil
            source.lastErrorMessage = nil
            source.consecutiveFailureDays = 0
            source.updatedAt = date
        }

        try await sources.save(source)
        return source
    }

    private static func requireFailureStatus(_ status: SourceFetchStatus) throws {
        guard status == .failed || status == .offline else {
            throw SourceManagementError.invalidFailureStatus
        }
    }
}
