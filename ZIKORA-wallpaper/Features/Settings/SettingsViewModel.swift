import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: UserSettings?
    @Published private(set) var loginItemStatus: LoginItemStatus = .unavailable
    @Published private(set) var storageStatistics: FileStoreStatistics?
    @Published private(set) var cacheLocation: ManagedCacheLocation?
    @Published private(set) var cleanupEstimate: WallpaperCleanupEstimate?
    @Published private(set) var slideShowCandidateCount = 0
    @Published private(set) var isLoading = false
    @Published var pendingCleanupConfirmation = false
    @Published var notice: OperationNotice?

    private let repository: any RepositoryStore
    private let loginItemCoordinator: LoginItemToggleCoordinator
    private let rotationScheduler: RotationScheduler
    private let cleanupUseCase: CleanupWallpapersUseCase
    private let cacheInspector: any ManagedCacheInspecting
    private let finder: FinderCacheDirectoryService
    private let clock: any Clock
    private let calendar: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating

    init(
        repository: any RepositoryStore,
        loginItemCoordinator: LoginItemToggleCoordinator,
        rotationScheduler: RotationScheduler,
        fileStore: any WallpaperFileStore,
        fileInventory: any ManagedFileInventoryProviding,
        cacheInspector: any ManagedCacheInspecting,
        finder: FinderCacheDirectoryService,
        clock: any Clock,
        calendar: any CalendarProviding,
        uuidGenerator: any UUIDGenerating
    ) {
        self.repository = repository
        self.loginItemCoordinator = loginItemCoordinator
        self.rotationScheduler = rotationScheduler
        self.cleanupUseCase = CleanupWallpapersUseCase(
            wallpapers: repository,
            fileStore: fileStore,
            fileInventory: fileInventory
        )
        self.cacheInspector = cacheInspector
        self.finder = finder
        self.clock = clock
        self.calendar = calendar
        self.uuidGenerator = uuidGenerator
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if var loaded = try await repository.loadSettings() {
                loaded.updatedAt = await clock.now()
                settings = loaded
            } else {
                let defaults = UserSettings.defaults(
                    id: await uuidGenerator.makeUUID(),
                    updatedAt: await clock.now()
                )
                try await repository.save(defaults)
                settings = defaults
            }
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }

        loginItemStatus = await loginItemCoordinator.synchronize()
        await refreshStorage()
        await refreshCandidates()
        await applyRotationSchedulerState()
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        let previousStatus = loginItemStatus
        loginItemStatus = await loginItemCoordinator.setEnabled(enabled)
        let isEnabled = loginItemStatus == .enabled || loginItemStatus == .requiresApproval
        do {
            try await persist { $0.launchAtLogin = isEnabled }
        } catch {
            loginItemStatus = previousStatus
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setWallpaperMode(_ mode: WallpaperMode) async {
        do {
            try await persist { $0.wallpaperMode = mode }
            await applyRotationSchedulerState()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setSlideshowOrder(_ order: SlideshowOrder) async {
        do {
            try await persist { $0.slideshowOrder = order }
            await rotationScheduler.refresh()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setSlideshowInterval(_ interval: SlideshowInterval) async {
        do {
            try await persist { $0.slideshowInterval = interval }
            await rotationScheduler.refresh()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func setRetentionPolicy(_ policy: RetentionPolicy) async {
        do {
            try await persist { $0.retentionPolicy = policy }
            await refreshCleanupEstimate()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func openCacheDirectory() async {
        do {
            _ = try await finder.openDirectory()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func requestCleanup() async {
        await refreshCleanupEstimate()
        pendingCleanupConfirmation = cleanupEstimate != nil
    }

    func confirmCleanup() async {
        pendingCleanupConfirmation = false
        guard let settings else { return }
        let today = LocalDay(
            containing: await clock.now(),
            calendar: await calendar.calendar()
        )
        do {
            let report = try await cleanupUseCase.execute(
                policy: settings.retentionPolicy,
                today: today,
                calendar: await calendar.calendar(),
                confirmed: true
            )
            await cacheInspector.invalidateStatistics()
            await refreshStorage()
            if report.hasFailures {
                notice = OperationNotice(
                    tone: .warning,
                    message: UserMessageCatalog.message(
                        for: AppFailure(code: .fileOperationFailed)
                    )
                )
            }
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    private func persist(
        _ mutate: (inout UserSettings) -> Void
    ) async throws {
        let previous: UserSettings
        if let settings {
            previous = settings
        } else {
            previous = UserSettings.defaults(
                id: await uuidGenerator.makeUUID(),
                updatedAt: await clock.now()
            )
        }
        var updated = previous
        mutate(&updated)
        updated.updatedAt = await clock.now()
        do {
            try await repository.save(updated)
            settings = updated
        } catch {
            settings = previous
            throw error
        }
    }

    private func applyRotationSchedulerState() async {
        guard let settings else { return }
        if settings.wallpaperMode == .daily {
            await rotationScheduler.stop()
        } else {
            await rotationScheduler.refresh()
        }
    }

    private func refreshStorage() async {
        do {
            storageStatistics = try await cacheInspector.statistics()
            cacheLocation = try await cacheInspector.location()
        } catch {
            storageStatistics = nil
        }
        await refreshCleanupEstimate()
    }

    private func refreshCleanupEstimate() async {
        guard let settings else { return }
        let today = LocalDay(
            containing: await clock.now(),
            calendar: await calendar.calendar()
        )
        cleanupEstimate = try? await cleanupUseCase.estimate(
            policy: settings.retentionPolicy,
            today: today,
            calendar: await calendar.calendar()
        )
    }

    private func refreshCandidates() async {
        slideShowCandidateCount = (try? await repository.allWallpapers().filter {
            $0.fileState == .available
        }.count) ?? 0
    }

    private static func userMessage(for error: Error) -> UserMessage {
        if let failure = error as? AppFailure {
            return UserMessageCatalog.message(for: failure)
        }
        if let repositoryError = error as? RepositoryError {
            switch repositoryError {
            case .notFound:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .missingConfiguration)
                )
            case .duplicateContentHash, .duplicateTaskKey, .invalidPersistedValue, .persistenceFailed:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .persistenceFailed)
                )
            }
        }
        return UserMessageCatalog.message(for: AppFailure(code: .unknown))
    }
}
