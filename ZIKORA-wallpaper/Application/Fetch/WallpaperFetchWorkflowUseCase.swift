import Foundation

/// Production implementation of the daily/manual wallpaper fetch state machine.
///
/// It owns the whole pipeline from source resolution through download,
/// validation, content hashing, atomic commit, desktop application, and
/// successful/failed fetch records. Automatic retries are recorded through
/// `PersistentRetryCoordinator`; manual failures never mutate automatic counts.
nonisolated struct WallpaperFetchWorkflowUseCase: WallpaperFetchWorkflow {
    private let repository: any RepositoryStore
    private let downloader: any ImageDownloading
    private let validator: any ImageValidating
    private let fileStore: any WallpaperFileStore
    private let hasher: any ImageContentHashing
    private let managedRootURL: URL
    private let setCurrentWallpaper: SetCurrentWallpaperUseCase
    private let retryCoordinator: PersistentRetryCoordinator
    private let retryScheduler: any RetryScheduling
    private let health: SourceHealthSettlementCoordinator
    private let logger: any AppLogging
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating
    private let cleanupUseCase: CleanupWallpapersUseCase

    init(
        repository: any RepositoryStore,
        downloader: any ImageDownloading,
        validator: any ImageValidating,
        fileStore: any WallpaperFileStore,
        hasher: any ImageContentHashing,
        managedRootURL: URL,
        setCurrentWallpaper: SetCurrentWallpaperUseCase,
        retryCoordinator: PersistentRetryCoordinator,
        retryScheduler: any RetryScheduling,
        health: SourceHealthSettlementCoordinator,
        logger: any AppLogging,
        clock: any Clock,
        calendarProvider: any CalendarProviding,
        uuidGenerator: any UUIDGenerating
    ) {
        self.repository = repository
        self.downloader = downloader
        self.validator = validator
        self.fileStore = fileStore
        self.hasher = hasher
        self.managedRootURL = managedRootURL
        self.setCurrentWallpaper = setCurrentWallpaper
        self.retryCoordinator = retryCoordinator
        self.retryScheduler = retryScheduler
        self.health = health
        self.logger = logger
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.uuidGenerator = uuidGenerator
        self.cleanupUseCase = CleanupWallpapersUseCase(
            wallpapers: repository,
            fileStore: fileStore,
            fileInventory: LocalManagedFileInventory(rootURL: managedRootURL)
        )
    }

    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        try Task.checkCancellation()
        progress(FetchProgress(phase: .checking, fraction: 0.05))

        let now = await clock.now()
        let calendar = await calendarProvider.calendar()
        let day = LocalDay(containing: now, calendar: calendar)
        let sources = try await repository.allSources()
        let schedule = try await repository.loadSchedule()
        let plannedSourceID = schedule?.sourceID(for: day.weekday(calendar: calendar))

        let prepared = try await PrepareDailyFetchRecordUseCase(
            repository: repository,
            clock: clock,
            calendarProvider: calendarProvider,
            uuidGenerator: uuidGenerator
        ).execute(taskKind: taskKind, plannedSourceID: plannedSourceID)

        if prepared.status == .success {
            return FetchExecutionResult(
                taskKind: taskKind,
                wallpaperID: prepared.wallpaperID,
                usedDefaultSource: prepared.usedDefaultSource
            )
        }

        let plannedAttemptFinalFailure = taskKind == .automaticDaily
            && prepared.automaticAttemptCount >= 3
            && !prepared.usedDefaultSource
        let resolution = ResolveSourceUseCase.resolve(
            plannedSourceID: plannedSourceID,
            defaultSourceID: schedule?.defaultSourceID,
            sources: sources,
            plannedAttemptFinalFailure: plannedAttemptFinalFailure
        )

        guard let sourceID = resolution.actualSourceID,
              let source = sources.first(where: { $0.id == sourceID }) else {
            var failed = prepared
            failed.lastAttemptAt = now
            failed.lastErrorCode = .missingConfiguration
            failed.status = .failed
            failed.nextRetryAt = nil
            try await repository.save(failed)
            throw AppFailure(code: .missingConfiguration)
        }

        var record = ResolveSourceUseCase().apply(
            to: prepared,
            plannedSourceID: plannedSourceID,
            defaultSourceID: schedule?.defaultSourceID,
            sources: sources,
            plannedAttemptFinalFailure: plannedAttemptFinalFailure
        )
        record.lastAttemptAt = now
        record.lastErrorCode = nil
        try await repository.save(record)
        progress(FetchProgress(phase: .resolvingSource, fraction: 0.2))

        return try await performAttempt(
            record: record,
            source: source,
            taskKind: taskKind,
            day: day,
            now: now,
            calendar: calendar,
            progress: progress
        )
    }

    private func performAttempt(
        record: DailyFetchRecord,
        source: WallpaperSource,
        taskKind: FetchTaskKind,
        day: LocalDay,
        now: Date,
        calendar: Calendar,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        progress(FetchProgress(phase: .downloading, fraction: 0.35))
        _ = try? await health.markRequestStarted(sourceID: source.id)

        do {
            let downloaded = try await downloader.download(from: source.url)
            defer { try? FileManager.default.removeItem(at: downloaded.temporaryFileURL) }

            progress(FetchProgress(phase: .validating, fraction: 0.45))
            let validated = try await validator.validate(
                fileAt: downloaded.temporaryFileURL,
                declaredMIMEType: downloaded.responseMIMEType
            )
            let format = try Self.wallpaperFormat(for: validated.formatIdentifier)

            progress(FetchProgress(phase: .hashing, fraction: 0.55))
            let decision = try await DeduplicateWallpaperUseCase(
                wallpapers: repository,
                hasher: hasher
            ).execute(fileAt: downloaded.temporaryFileURL)

            progress(FetchProgress(phase: .committing, fraction: 0.65))
            let wallpaper: Wallpaper
            let didCreateNewWallpaper: Bool
            if let existing = decision.existingWallpaper, existing.fileState == .available {
                wallpaper = existing
                didCreateNewWallpaper = false
            } else if var existing = decision.existingWallpaper {
                let relativePath = try await fileStore.commitTemporaryFile(
                    at: downloaded.temporaryFileURL,
                    preferredExtension: format.preferredFileExtension
                )
                guard let managedPath = ManagedRelativePath(rawValue: relativePath) else {
                    throw AppFailure(code: .fileOperationFailed)
                }
                existing.relativePath = managedPath
                existing.fileState = .available
                existing.fileSize = downloaded.byteCount
                existing.pixelWidth = validated.pixelWidth
                existing.pixelHeight = validated.pixelHeight
                existing.format = format
                try await repository.save(existing)
                wallpaper = existing
                didCreateNewWallpaper = false
            } else {
                let relativePath = try await fileStore.commitTemporaryFile(
                    at: downloaded.temporaryFileURL,
                    preferredExtension: format.preferredFileExtension
                )
                guard let managedPath = ManagedRelativePath(rawValue: relativePath) else {
                    throw AppFailure(code: .fileOperationFailed)
                }
                wallpaper = Wallpaper(
                    id: WallpaperID(rawValue: await uuidGenerator.makeUUID()),
                    contentHash: decision.contentHash.value,
                    sourceID: source.id,
                    sourceNameSnapshot: source.name,
                    relativePath: managedPath,
                    downloadDay: day,
                    createdAt: now,
                    pixelWidth: validated.pixelWidth,
                    pixelHeight: validated.pixelHeight,
                    fileSize: downloaded.byteCount,
                    format: format,
                    fileState: .available,
                    isCurrent: false
                )
                try await repository.save(wallpaper)
                didCreateNewWallpaper = true
            }

            progress(FetchProgress(phase: .applying, fraction: 0.8))
            do {
                _ = try await setCurrentWallpaper.execute(
                    wallpaperID: wallpaper.id,
                    fileURL: fileURL(for: wallpaper)
                )
            } catch {
                if didCreateNewWallpaper {
                    try? await fileStore.remove(relativePath: wallpaper.relativePath.rawValue)
                    try? await repository.delete(id: wallpaper.id)
                }
                throw error
            }

            progress(FetchProgress(phase: .recordingSuccess, fraction: 0.9))
            _ = try await AssociateWallpaperWithFetchUseCase(records: repository).execute(
                record: record,
                wallpaper: wallpaper,
                actualSourceID: source.id,
                attemptedAt: now
            )
            _ = try? await health.markSuccess(sourceID: source.id)

            progress(FetchProgress(phase: .cleaning, fraction: 0.95))
            let settings = try await repository.loadSettings()
            _ = try? await cleanupUseCase.execute(
                policy: settings?.retentionPolicy ?? AppDefaults.retentionPolicy,
                today: day,
                calendar: calendar,
                confirmed: true
            )

            logger.log(AppLogRecord(
                category: .application,
                level: .information,
                event: .operationSucceeded,
                url: source.url
            ))
            return FetchExecutionResult(
                taskKind: taskKind,
                wallpaperID: wallpaper.id,
                usedDefaultSource: record.usedDefaultSource
            )
        } catch {
            let failure = Self.normalize(error)
            logger.log(AppLogRecord(
                category: .networking,
                level: .warning,
                event: .operationFailed,
                errorCode: failure.code,
                url: source.url
            ))
            _ = try? await health.markRequestFailed(
                sourceID: source.id,
                status: failure.code == .networkUnavailable ? .offline : .failed,
                errorCode: failure.code,
                message: failure.localizedDescription
            )

            if taskKind == .manualUpdate {
                var failed = record
                failed.status = .failed
                failed.lastAttemptAt = now
                failed.nextRetryAt = nil
                failed.lastErrorCode = failure.code
                try await repository.save(failed)
                throw failure
            }

            return try await handleAutomaticFailure(
                record: record,
                source: source,
                failure: failure,
                day: day,
                now: now,
                calendar: calendar,
                progress: progress
            )
        }
    }

    private func handleAutomaticFailure(
        record: DailyFetchRecord,
        source: WallpaperSource,
        failure: AppFailure,
        day: LocalDay,
        now: Date,
        calendar: Calendar,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        if record.usedDefaultSource {
            var final = record
            final.status = .failed
            final.nextRetryAt = nil
            final.lastErrorCode = failure.code
            try await repository.save(final)
            _ = try? await health.settleFailure(
                sourceID: source.id,
                status: failure.code == .networkUnavailable ? .offline : .failed,
                errorCode: failure.code,
                message: failure.localizedDescription
            )
            throw failure
        }

        var failingRecord = record
        failingRecord.lastErrorCode = failure.code
        try await repository.save(failingRecord)
        let updated = try await retryCoordinator.recordFailure(
            for: failingRecord,
            at: now,
            usedDefaultSource: false
        )

        if updated.status == .retryScheduled, let retryAt = updated.nextRetryAt {
            await retryScheduler.scheduleCheck(at: retryAt)
            throw failure
        }

        if updated.automaticAttemptCount == 3,
           updated.usedDefaultSource,
           !record.usedDefaultSource {
            let sources = try await repository.allSources()
            let schedule = try await repository.loadSchedule()
            let resolution = ResolveSourceUseCase.resolve(
                plannedSourceID: record.plannedSourceID,
                defaultSourceID: schedule?.defaultSourceID,
                sources: sources,
                plannedAttemptFinalFailure: true
            )
            if let defaultSourceID = resolution.actualSourceID,
               resolution.usedDefaultSource,
               let defaultSource = sources.first(where: { $0.id == defaultSourceID }) {
                var next = updated
                next.actualSourceID = defaultSourceID
                try await repository.save(next)
                return try await performAttempt(
                    record: next,
                    source: defaultSource,
                    taskKind: .automaticDaily,
                    day: day,
                    now: now,
                    calendar: calendar,
                    progress: progress
                )
            }

            var final = updated
            final.usedDefaultSource = false
            final.status = .failed
            try await repository.save(final)
        }

        _ = try? await health.settleFailure(
            sourceID: source.id,
            status: failure.code == .networkUnavailable ? .offline : .failed,
            errorCode: failure.code,
            message: failure.localizedDescription
        )
        throw failure
    }

    private func fileURL(for wallpaper: Wallpaper) -> URL {
        managedRootURL.appendingPathComponent(wallpaper.relativePath.rawValue)
    }

    private static func wallpaperFormat(for identifier: String) throws -> WallpaperFormat {
        let normalized = identifier.lowercased()
        if normalized.contains("jpeg") || normalized.contains("jpg") {
            return .jpeg
        }
        if normalized.contains("png") {
            return .png
        }
        if normalized.contains("heic") || normalized.contains("heif") {
            return .heic
        }
        if normalized.contains("webp") {
            return .webP
        }
        throw AppFailure(code: .unsupportedImage, recoveryAction: .editSource)
    }

    private static func normalize(_ error: Error) -> AppFailure {
        if error is CancellationError {
            return AppFailure(code: .operationCancelled)
        }
        if let failure = error as? AppFailure {
            return failure
        }
        if let currentError = error as? CurrentWallpaperUpdateError {
            switch currentError {
            case .noDisplaysAvailable, .allDisplaysFailed:
                return AppFailure(code: .wallpaperUpdateFailed)
            case .fileUnavailable, .invalidFileURL:
                return AppFailure(code: .fileOperationFailed)
            case .wallpaperNotFound:
                return AppFailure(code: .unknown)
            case .repository:
                return AppFailure(code: .persistenceFailed)
            }
        }
        return AppFailure(code: .unknown)
    }
}
