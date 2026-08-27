import Foundation

@MainActor
final class AppServices {
    let repository: any RepositoryStore
    let managedRootURL: URL
    let fileStore: any WallpaperFileStore
    let fileInventory: any ManagedFileInventoryProviding
    let thumbnailProvider: any ThumbnailProviding
    let cacheInspector: any ManagedCacheInspecting
    let finder: FinderCacheDirectoryService
    let loginItemCoordinator: LoginItemToggleCoordinator
    let rotationScheduler: RotationScheduler
    let setCurrentWallpaper: SetCurrentWallpaperUseCase
    let commandCenter: WallpaperCommandCenter
    let sourceFetcher: any SourceFetchOrchestrating
    let retryScheduler: PersistentRetryScheduler
    let automaticTrigger: AutomaticFetchTriggerCoordinator
    let lifecycle: WindowLifecycleCoordinator

    private let workflow: WallpaperFetchWorkflowUseCase
    private let retryProxy: RetryWorkflowProxy
    private let eventProvider: any SystemEventProviding
    private var eventTask: Task<Void, Never>?
    private var started = false

    init(
        repository: any RepositoryStore,
        managedRootURL: URL,
        clock: any Clock,
        calendar: any CalendarProviding,
        uuidGenerator: any UUIDGenerating,
        randomSelector: any RandomSelecting,
        logger: any AppLogging
    ) throws {
        self.repository = repository
        self.managedRootURL = managedRootURL

        let fileStore = try AtomicWallpaperFileStore(
            rootURL: managedRootURL,
            clock: clock,
            calendarProvider: calendar,
            uuidGenerator: uuidGenerator
        )
        self.fileStore = fileStore
        self.fileInventory = LocalManagedFileInventory(rootURL: managedRootURL)
        self.thumbnailProvider = try ThumbnailPipeline(rootURL: managedRootURL)
        self.cacheInspector = try ManagedCacheService(
            rootURL: managedRootURL,
            fileStore: fileStore
        )
        self.finder = FinderCacheDirectoryService(rootURL: managedRootURL)
        self.loginItemCoordinator = LoginItemToggleCoordinator(
            manager: SMAppLoginItemManager()
        )
        let setCurrentWallpaper = SetCurrentWallpaperUseCase(
            wallpapers: repository,
            desktopWallpaperSetter: AppKitDesktopWallpaperSetter()
        )
        self.setCurrentWallpaper = setCurrentWallpaper

        let rotationScheduler = RotationScheduler(
            settings: repository,
            candidates: RepositoryRotationCandidateProvider(repository: repository),
            applier: WallpaperRotationApplier(
                repository: repository,
                managedRootURL: managedRootURL,
                setter: AppKitDesktopWallpaperSetter()
            ),
            selector: randomSelector
        )
        self.rotationScheduler = rotationScheduler

        let retryProxy = RetryWorkflowProxy()
        let retryCoordinator = PersistentRetryCoordinator(
            records: repository,
            clock: clock,
            calendarProvider: calendar
        )
        let health = SourceHealthSettlementCoordinator(
            health: UpdateSourceHealthUseCase(sources: repository),
            clock: clock,
            calendarProvider: calendar
        )
        let retryScheduler = PersistentRetryScheduler(
            workflow: retryProxy,
            records: repository,
            clock: clock,
            calendarProvider: calendar
        )
        self.retryScheduler = retryScheduler
        self.retryProxy = retryProxy

        let workflow = WallpaperFetchWorkflowUseCase(
            repository: repository,
            downloader: URLSessionImageDownloader(logger: logger),
            validator: ImageIOImageValidator(),
            fileStore: fileStore,
            hasher: SHA256ImageHasher(),
            managedRootURL: managedRootURL,
            setCurrentWallpaper: setCurrentWallpaper,
            retryCoordinator: retryCoordinator,
            retryScheduler: retryScheduler,
            health: health,
            logger: logger,
            clock: clock,
            calendarProvider: calendar,
            uuidGenerator: uuidGenerator
        )
        self.workflow = workflow

        let orchestrator = FetchOrchestrator(workflow: workflow)
        self.sourceFetcher = orchestrator
        self.commandCenter = WallpaperCommandCenter(
            orchestrator: orchestrator,
            repository: repository,
            setCurrentWallpaper: setCurrentWallpaper,
            managedRootURL: managedRootURL,
            randomSelector: randomSelector
        )
        self.automaticTrigger = AutomaticFetchTriggerCoordinator(
            checker: DailyFetchChecker(
                settings: repository,
                records: repository,
                workflow: orchestrator,
                clock: clock,
                calendarProvider: calendar
            )
        )
        self.lifecycle = WindowLifecycleCoordinator(settings: repository)
        self.eventProvider = WorkspaceSystemEventProvider()
    }

    func start() async {
        guard !started else { return }
        started = true

        await synchronizeLoginItemConfiguration()

        await retryProxy.set(workflow)
        await retryScheduler.scheduleNextDue()
        await rotationScheduler.start()
        await commandCenter.refresh()

        let trigger = automaticTrigger
        let scheduler = retryScheduler
        let commandCenter = commandCenter
        let events = eventProvider.events()
        eventTask = Task { @MainActor in
            for await event in events {
                commandCenter.markRunning()
                _ = try? await trigger.handle(event)
                await scheduler.scheduleNextDue()
                await commandCenter.refresh()
                commandCenter.markFinished()
            }
        }
    }

    private func synchronizeLoginItemConfiguration() async {
        guard let settings = try? await repository.loadSettings(), settings.launchAtLogin else {
            return
        }

        let status = await loginItemCoordinator.synchronize()
        guard status == .disabled else { return }
        _ = await loginItemCoordinator.setEnabled(true)
    }

    func shutdown() async {
        eventTask?.cancel()
        eventTask = nil
        await rotationScheduler.stop()
        await retryScheduler.cancelScheduledCheck()
    }
}

private actor RetryWorkflowProxy: WallpaperFetchWorkflow {
    private var workflow: (any WallpaperFetchWorkflow)?

    func set(_ workflow: any WallpaperFetchWorkflow) {
        self.workflow = workflow
    }

    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        guard let workflow else {
            throw AppFailure(code: .unknown)
        }
        return try await workflow.execute(
            taskKind: taskKind,
            reason: reason,
            progress: progress
        )
    }
}

private struct RepositoryRotationCandidateProvider: RotationCandidateProviding, Sendable {
    let repository: any WallpaperRepository

    func candidates() async throws -> [Wallpaper] {
        try await repository.allWallpapers().filter {
            $0.fileState == .available
        }
    }
}

private struct WallpaperRotationApplier: RotationWallpaperApplying, Sendable {
    let repository: any WallpaperRepository
    let managedRootURL: URL
    let setter: any DesktopWallpaperSetting

    func apply(wallpaper: Wallpaper) async throws {
        let fileURL = managedRootURL.appendingPathComponent(
            wallpaper.relativePath.rawValue
        )
        _ = try await SetCurrentWallpaperUseCase(
            wallpapers: repository,
            desktopWallpaperSetter: setter
        ).execute(wallpaperID: wallpaper.id, fileURL: fileURL)
    }
}
