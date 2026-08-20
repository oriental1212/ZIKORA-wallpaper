import Foundation

actor RotationScheduler {
    private let settings: any SettingsRepository
    private let candidates: any RotationCandidateProviding
    private let applier: any RotationWallpaperApplying
    private let selector: any RandomSelecting
    private let sleeper: any AsyncSleeping
    private var task: Task<Void, Never>?
    private var taskToken: UUID?
    private var previousID: WallpaperID?

    init(
        settings: any SettingsRepository,
        candidates: any RotationCandidateProviding,
        applier: any RotationWallpaperApplying,
        selector: any RandomSelecting = SystemRandomSelector(),
        sleeper: any AsyncSleeping = SystemAsyncSleeper()
    ) {
        self.settings = settings
        self.candidates = candidates
        self.applier = applier
        self.selector = selector
        self.sleeper = sleeper
    }

    func start() {
        guard task == nil else { return }
        let token = UUID()
        taskToken = token
        task = Task { [weak self] in
            await self?.runLoop(token: token)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        taskToken = nil
    }

    func refresh() {
        stop()
        start()
    }

    func pauseForSleep() {
        stop()
    }

    func resumeAfterWake() {
        refresh()
    }

    func isRunning() -> Bool {
        task != nil
    }

    func waitUntilStopped() async {
        while task != nil {
            await Task.yield()
        }
    }

    private func runLoop(token: UUID) async {
        defer {
            if taskToken == token {
                task = nil
                taskToken = nil
            }
        }
        while !Task.isCancelled {
            do {
                let settings = try await settings.loadSettings()
                guard settings?.wallpaperMode == .slideshow else { return }
                let available = try await candidates.candidates().filter {
                    $0.fileState == .available
                }
                guard !available.isEmpty else { return }

                try await sleeper.sleep(for: settings?.slideshowInterval.duration ?? AppDefaults.slideshowInterval.duration)
                guard !Task.isCancelled else { return }

                let next: Wallpaper?
                if settings?.slideshowOrder == .chronological {
                    next = WallpaperSelectionPolicy.chronological(available).first
                } else {
                    next = await WallpaperSelectionPolicy.selectRandom(
                        available,
                        previousID: previousID,
                        selector: selector
                    )
                }
                guard let next else { return }
                try await applier.apply(wallpaper: next)
                previousID = next.id
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }
}
