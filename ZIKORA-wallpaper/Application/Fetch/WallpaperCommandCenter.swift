import Combine
import Foundation

/// Main-actor shared command state observed by Dashboard and Menu Bar.
@MainActor
final class WallpaperCommandCenter: ObservableObject {
    @Published private(set) var currentWallpaper: Wallpaper?
    @Published private(set) var isRunning = false
    @Published private(set) var isUpdating = false
    @Published private(set) var isNexting = false
    @Published private(set) var progress: FetchProgress?
    @Published private(set) var notice: OperationNotice?
    @Published private(set) var lastSucceededAt: Date?
    @Published private(set) var reusedCurrentWallpaper = false

    private let orchestrator: any FetchOrchestrating
    private let repository: any RepositoryStore
    private let setCurrentWallpaper: SetCurrentWallpaperUseCase
    private let managedRootURL: URL
    private let randomSelector: any RandomSelecting

    init(
        orchestrator: any FetchOrchestrating,
        repository: any RepositoryStore,
        setCurrentWallpaper: SetCurrentWallpaperUseCase,
        managedRootURL: URL,
        randomSelector: any RandomSelecting
    ) {
        self.orchestrator = orchestrator
        self.repository = repository
        self.setCurrentWallpaper = setCurrentWallpaper
        self.managedRootURL = managedRootURL
        self.randomSelector = randomSelector
    }

    func refresh() async {
        currentWallpaper = try? await repository.allWallpapers().first(where: \.isCurrent)
    }

    func markRunning() {
        isRunning = true
    }

    func markFinished() {
        isRunning = false
        progress = nil
        isUpdating = false
        isNexting = false
    }

    func updateNow() async {
        guard !isRunning else {
            return
        }
        let previous = currentWallpaper
        isRunning = true
        isUpdating = true
        progress = FetchProgress(phase: .checking, fraction: nil)
        notice = nil

        do {
            let result = try await orchestrator.run(
                taskKind: .manualUpdate,
                reason: .manual
            )
            await refresh()
            reusedCurrentWallpaper = previous?.id == result.wallpaperID
            lastSucceededAt = Date()
        } catch {
            reusedCurrentWallpaper = false
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }

        isRunning = false
        isUpdating = false
        progress = nil
    }

    func nextWallpaper() async {
        guard !isRunning else {
            return
        }
        isRunning = true
        isNexting = true
        notice = nil

        let wallpapers = (try? await repository.allWallpapers()) ?? []
        let settings = try? await repository.loadSettings()
        let currentID = currentWallpaper?.id ?? wallpapers.first(where: \.isCurrent)?.id
        let candidates = wallpapers.filter {
            $0.fileState == .available && $0.id != currentID
        }

        let next: Wallpaper?
        if settings?.wallpaperMode == .slideshow,
           settings?.slideshowOrder == .chronological {
            next = WallpaperSelectionPolicy.chronological(candidates).first
        } else if settings?.wallpaperMode == .slideshow {
            next = await WallpaperSelectionPolicy.selectRandom(
                wallpapers,
                previousID: currentID,
                selector: randomSelector
            )
        } else {
            next = WallpaperSelectionPolicy.manualDaily(candidates).first
        }

        guard let next else {
            notice = OperationNotice(
                tone: .warning,
                message: UserMessageCatalog.message(
                    for: AppFailure(code: .noWallpaperCandidate)
                )
            )
            isRunning = false
            isNexting = false
            return
        }

        do {
            _ = try await setCurrentWallpaper.execute(
                wallpaperID: next.id,
                fileURL: managedRootURL.appendingPathComponent(next.relativePath.rawValue)
            )
            await refresh()
            reusedCurrentWallpaper = false
            lastSucceededAt = Date()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }

        isRunning = false
        isNexting = false
    }

    private static func userMessage(for error: Error) -> UserMessage {
        if let failure = error as? AppFailure {
            return UserMessageCatalog.message(for: failure)
        }
        if let currentError = error as? CurrentWallpaperUpdateError {
            switch currentError {
            case .fileUnavailable, .invalidFileURL:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .fileOperationFailed)
                )
            case .noDisplaysAvailable, .allDisplaysFailed:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .wallpaperUpdateFailed)
                )
            case .wallpaperNotFound, .repository:
                return UserMessageCatalog.message(
                    for: AppFailure(code: .unknown)
                )
            }
        }
        return UserMessageCatalog.message(for: AppFailure(code: .unknown))
    }
}
