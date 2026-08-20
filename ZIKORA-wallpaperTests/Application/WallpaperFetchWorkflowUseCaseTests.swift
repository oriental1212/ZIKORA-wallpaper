import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct WallpaperFetchWorkflowUseCaseTests {
    @Test("A successful fetch commits one wallpaper, applies it, and records success")
    func successRecordsWallpaper() async throws {
        let context = try makeContext(settings: UserSettings.defaults(id: UUID(), updatedAt: date()))
        let downloader = ScriptedDownloader()
        await downloader.setPlan(.success(data: Data("image".utf8), mimeType: "image/png"))
        let workflow = try makeWorkflow(
            context: context,
            downloader: downloader,
            hasher: FixedContentHasher(value: "success-hash"),
            validator: FixedValidator(format: "public.png")
        )

        let result = try await workflow.execute(
            taskKind: .manualUpdate,
            reason: .manual,
            progress: { _ in }
        )

        let wallpapers = try await context.repository.allWallpapers()
        let record = try #require(
            try await context.repository.allRecords().first {
                $0.taskKind == .manualUpdate
            }
        )
        #expect(wallpapers.count == 1)
        #expect(wallpapers[0].isCurrent)
        #expect(wallpapers[0].contentHash == "success-hash")
        #expect(record.status == .success)
        #expect(record.wallpaperID == result.wallpaperID)
        #expect(FileManager.default.fileExists(
            atPath: context.root.appendingPathComponent(
                wallpapers[0].relativePath.rawValue
            ).path
        ))
        #expect(try await context.repository.source(id: contextSources[0].id)?
            .lastFetchStatus == .success)
    }

    @Test("Automatic network failure schedules a 30 minute retry without changing current")
    func automaticFailureSchedulesRetry() async throws {
        let context = try makeContext(settings: UserSettings.defaults(id: UUID(), updatedAt: date()))
        let downloader = ScriptedDownloader()
        await downloader.setPlan(.failure(AppFailure(code: .networkUnavailable)))
        let workflow = try makeWorkflow(
            context: context,
            downloader: downloader,
            hasher: FixedContentHasher(value: "unused"),
            validator: FixedValidator(format: "public.png")
        )

        await #expect(throws: AppFailure(code: .networkUnavailable)) {
            try await workflow.execute(
                taskKind: .automaticDaily,
                reason: .applicationStarted,
                progress: { _ in }
            )
        }

        let record = try #require(
            try await context.repository.allRecords().first {
                $0.taskKind == .automaticDaily
            }
        )
        #expect(record.status == .retryScheduled)
        #expect(record.automaticAttemptCount == 1)
        #expect(record.nextRetryAt == date().addingTimeInterval(30 * 60))
        #expect(try await context.repository.allWallpapers().isEmpty)
        #expect(try await context.repository.source(id: contextSources[0].id)?
            .lastFetchStatus == .offline)
        #expect(await context.scheduler.scheduledDates().count == 1)
    }

    @Test("Manual failure records a manual failure and never touches automatic attempts")
    func manualFailureKeepsAutomaticCountUntouched() async throws {
        let context = try makeContext(settings: UserSettings.defaults(id: UUID(), updatedAt: date()))
        let downloader = ScriptedDownloader()
        await downloader.setPlan(.failure(AppFailure(code: .requestTimedOut)))
        let workflow = try makeWorkflow(
            context: context,
            downloader: downloader,
            hasher: FixedContentHasher(value: "unused"),
            validator: FixedValidator(format: "public.png")
        )

        await #expect(throws: AppFailure(code: .requestTimedOut)) {
            try await workflow.execute(
                taskKind: .manualUpdate,
                reason: .manual,
                progress: { _ in }
            )
        }

        let record = try #require(
            try await context.repository.allRecords().first {
                $0.taskKind == .manualUpdate
            }
        )
        #expect(record.status == .failed)
        #expect(record.automaticAttemptCount == 0)
        #expect(await context.scheduler.scheduledDates().isEmpty)
    }

    @Test("Three planned-source failures fall back to the default source once")
    func thirdFailureUsesDefaultSourceOnce() async throws {
        let context = try makeContext(settings: UserSettings.defaults(id: UUID(), updatedAt: date()))
        let downloader = ScriptedDownloader()
        await downloader.setPlan(.sequence([
            .failure(AppFailure(code: .networkUnavailable)),
            .failure(AppFailure(code: .networkUnavailable)),
            .failure(AppFailure(code: .networkUnavailable)),
            .success(data: Data("default-image".utf8), mimeType: "image/png")
        ]))
        let workflow = try makeWorkflow(
            context: context,
            downloader: downloader,
            hasher: FixedContentHasher(value: "default-hash"),
            validator: FixedValidator(format: "public.png")
        )

        _ = try? await workflow.execute(
            taskKind: .automaticDaily,
            reason: .retryDue,
            progress: { _ in }
        )
        _ = try? await workflow.execute(
            taskKind: .automaticDaily,
            reason: .retryDue,
            progress: { _ in }
        )
        let result = try await workflow.execute(
            taskKind: .automaticDaily,
            reason: .retryDue,
            progress: { _ in }
        )

        let record = try #require(
            try await context.repository.allRecords().first {
                $0.taskKind == .automaticDaily
            }
        )
        #expect(record.status == .success)
        #expect(record.usedDefaultSource)
        #expect(record.actualSourceID == contextSources[1].id)
        #expect(record.automaticAttemptCount == 3)
        #expect(result.usedDefaultSource)
        #expect(try await context.repository.source(id: contextSources[1].id)?
            .lastFetchStatus == .success)
        #expect(try await context.repository.allWallpapers().count == 1)
    }

    @Test("Identical content reuses one physical wallpaper and links the new record")
    func duplicateContentReusesWallpaper() async throws {
        let existing = Wallpaper(
            id: WallpaperID(rawValue: UUID()),
            contentHash: "same-hash",
            sourceID: contextSources[0].id,
            sourceNameSnapshot: contextSources[0].name,
            relativePath: ManagedRelativePath(rawValue: "2026-08-19/existing.png")!,
            downloadDay: LocalDay(rawValue: "2026-08-19")!,
            createdAt: date(),
            pixelWidth: 2,
            pixelHeight: 2,
            fileSize: 5,
            format: .png,
            fileState: .missing,
            isCurrent: false
        )
        let repository = try InMemoryRepositoryStore(
            sources: contextSources,
            wallpapers: [existing],
            schedule: contextSchedule,
            settings: UserSettings.defaults(id: UUID(), updatedAt: date())
        )
        let context = try makeContext(repository: repository)
        let downloader = ScriptedDownloader()
        await downloader.setPlan(.success(data: Data("image".utf8), mimeType: "image/png"))
        let workflow = try makeWorkflow(
            context: context,
            downloader: downloader,
            hasher: FixedContentHasher(value: "same-hash"),
            validator: FixedValidator(format: "public.png")
        )

        let result = try await workflow.execute(
            taskKind: .manualUpdate,
            reason: .manual,
            progress: { _ in }
        )

        let wallpapers = try await repository.allWallpapers()
        #expect(wallpapers.count == 1)
        #expect(wallpapers[0].id == existing.id)
        #expect(wallpapers[0].fileState == .available)
        #expect(wallpapers[0].isCurrent)
        #expect(result.wallpaperID == existing.id)
    }

    private func makeContext(
        settings: UserSettings
    ) throws -> WorkflowContext {
        try makeContext(
            repository: try InMemoryRepositoryStore(
                sources: contextSources,
                schedule: contextSchedule,
                settings: settings
            )
        )
    }

    private func makeContext(
        repository: any RepositoryStore
    ) throws -> WorkflowContext {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileStore = try AtomicWallpaperFileStore(
            rootURL: root,
            clock: FixedClock(date: date()),
            calendarProvider: FixedCalendarProvider(value: calendar),
            uuidGenerator: FixedUUIDGenerator(value: UUID())
        )
        return WorkflowContext(
            repository: repository,
            root: root,
            fileStore: fileStore,
            scheduler: RecordingRetryScheduler()
        )
    }

    private func makeWorkflow(
        context: WorkflowContext,
        downloader: any ImageDownloading,
        hasher: any ImageContentHashing,
        validator: any ImageValidating
    ) throws -> WallpaperFetchWorkflowUseCase {
        let setter = StubDesktopSetter(successCount: 1)
        let retryCoordinator = PersistentRetryCoordinator(
            records: context.repository,
            clock: FixedClock(date: date()),
            calendarProvider: FixedCalendarProvider(value: calendar)
        )
        let health = SourceHealthSettlementCoordinator(
            health: UpdateSourceHealthUseCase(sources: context.repository),
            clock: FixedClock(date: date()),
            calendarProvider: FixedCalendarProvider(value: calendar)
        )
        return WallpaperFetchWorkflowUseCase(
            repository: context.repository,
            downloader: downloader,
            validator: validator,
            fileStore: context.fileStore,
            hasher: hasher,
            managedRootURL: context.root,
            setCurrentWallpaper: SetCurrentWallpaperUseCase(
                wallpapers: context.repository,
                desktopWallpaperSetter: setter
            ),
            retryCoordinator: retryCoordinator,
            retryScheduler: context.scheduler,
            health: health,
            logger: NoOpAppLogger(),
            clock: FixedClock(date: date()),
            calendarProvider: FixedCalendarProvider(value: calendar),
            uuidGenerator: FixedUUIDGenerator(value: UUID())
        )
    }

    private var contextSources: [WallpaperSource] {
        [
            makeSource(
                id: sourceID(1),
                name: "Planned",
                url: URL(string: "https://example.test/planned")!
            ),
            makeSource(
                id: sourceID(2),
                name: "Default",
                url: URL(string: "https://example.test/default")!
            )
        ]
    }

    private var contextSchedule: WeeklySchedule {
        let schedule = WeeklySchedule(
            id: UUID(),
            mondaySourceID: sourceID(1),
            tuesdaySourceID: sourceID(1),
            wednesdaySourceID: sourceID(1),
            thursdaySourceID: sourceID(1),
            fridaySourceID: sourceID(1),
            saturdaySourceID: sourceID(1),
            sundaySourceID: sourceID(1),
            defaultSourceID: sourceID(2),
            updatedAt: date()
        )
        return schedule
    }

    private func makeSource(id: SourceID, name: String, url: URL) -> WallpaperSource {
        WallpaperSource(
            id: id,
            name: name,
            url: url,
            isEnabled: true,
            createdAt: date(),
            updatedAt: date(),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }

    private func sourceID(_ value: UInt8) -> SourceID {
        SourceID(rawValue: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value)
        ))
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .gmt
        return value
    }

    private func date() -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 19,
            hour: 12
        ))!
    }
}

private struct WorkflowContext {
    let repository: any RepositoryStore
    let root: URL
    let fileStore: AtomicWallpaperFileStore
    let scheduler: RecordingRetryScheduler
}

private actor ScriptedDownloader: ImageDownloading {
    enum Plan: Sendable {
        case success(data: Data, mimeType: String)
        case failure(AppFailure)
        case sequence([Plan])
    }

    private var plan: Plan = .failure(AppFailure(code: .unknown))

    func setPlan(_ plan: Plan) {
        self.plan = plan
    }

    func download(from url: URL) async throws -> DownloadedImage {
        switch nextPlan() {
        case .success(let data, let mimeType):
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("workflow-download-\(UUID().uuidString)")
            try data.write(to: fileURL)
            return DownloadedImage(
                temporaryFileURL: fileURL,
                responseMIMEType: mimeType,
                byteCount: Int64(data.count)
            )
        case .failure(let error):
            throw error
        case .sequence:
            throw AppFailure(code: .unknown)
        }
    }

    private func nextPlan() -> Plan {
        guard case .sequence(var plans) = plan, !plans.isEmpty else {
            return plan
        }
        let next = plans.removeFirst()
        plan = plans.isEmpty ? .sequence(plans) : .sequence(plans)
        return next
    }
}

private struct FixedContentHasher: ImageContentHashing {
    let value: String

    func hash(fileAt url: URL) async throws -> ContentHash {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? 0
        return ContentHash(value: value, byteCount: Int64(size))
    }
}

private struct FixedValidator: ImageValidating {
    let format: String

    func validate(fileAt url: URL, declaredMIMEType: String?) async throws -> ValidatedImage {
        ValidatedImage(
            pixelWidth: 10,
            pixelHeight: 10,
            formatIdentifier: format
        )
    }
}

private struct StubDesktopSetter: DesktopWallpaperSetting {
    let successCount: Int

    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult] {
        (0..<successCount).map { index in
            DisplayWallpaperResult(
                displayID: DisplayID(rawValue: String(index)),
                succeeded: true
            )
        }
    }
}

private actor RecordingRetryScheduler: RetryScheduling {
    private var dates: [Date] = []

    func scheduleCheck(at date: Date) {
        dates.append(date)
    }

    func cancelScheduledCheck() {}

    func scheduledDates() -> [Date] {
        dates
    }
}
