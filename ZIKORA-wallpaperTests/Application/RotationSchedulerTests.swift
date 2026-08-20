import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct RotationSchedulerTests {
    @Test("Scheduler owns one task and refresh cancels the old loop")
    func oneTaskAndRefresh() async throws {
        let settings = try InMemoryRepositoryStore(settings: slideshowSettings())
        let sleeper = ControlledSleeper()
        let source = CandidateSource(wallpapers: [makeWallpaper(id: 1)])
        let applier = RecordingApplier()
        let scheduler = RotationScheduler(
            settings: settings,
            candidates: source,
            applier: applier,
            selector: FixedRandomSelector(value: 0),
            sleeper: sleeper
        )

        await scheduler.start()
        await scheduler.start()
        await Task.yield()
        #expect(await scheduler.isRunning())
        await scheduler.refresh()
        #expect(await sleeper.maximumActiveCount() == 1)
        await scheduler.stop()
    }

    @Test("No candidates stop the loop without applying or spinning")
    func emptyCandidatesStop() async throws {
        let settings = try InMemoryRepositoryStore(settings: slideshowSettings())
        let sleeper = ControlledSleeper()
        let applier = RecordingApplier()
        let scheduler = RotationScheduler(
            settings: settings,
            candidates: CandidateSource(wallpapers: []),
            applier: applier,
            sleeper: sleeper
        )

        await scheduler.start()
        await scheduler.waitUntilStopped()
        #expect(await scheduler.isRunning() == false)
        #expect(await applier.applicationCount() == 0)
        #expect(await sleeper.callCount() == 0)
    }

    @Test("Sleep pauses and wake resumes with a fresh candidate evaluation")
    func sleepWake() async throws {
        let settings = try InMemoryRepositoryStore(settings: slideshowSettings())
        let sleeper = ControlledSleeper()
        let source = CandidateSource(wallpapers: [makeWallpaper(id: 1)])
        let scheduler = RotationScheduler(
            settings: settings,
            candidates: source,
            applier: RecordingApplier(),
            sleeper: sleeper
        )

        await scheduler.start()
        await Task.yield()
        await scheduler.pauseForSleep()
        #expect(await scheduler.isRunning() == false)
        await scheduler.resumeAfterWake()
        #expect(await scheduler.isRunning())
        await scheduler.stop()
    }

    private func slideshowSettings() -> UserSettings {
        var value = UserSettings.defaults(id: UUID(), updatedAt: Date())
        value.wallpaperMode = .slideshow
        value.slideshowInterval = .fiveMinutes
        return value
    }

    private func makeWallpaper(id: UInt8) -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id))),
            contentHash: "hash-\(id)", sourceID: nil, sourceNameSnapshot: "source",
            relativePath: ManagedRelativePath(rawValue: "2026-08-19/\(id).jpg")!,
            downloadDay: LocalDay(rawValue: "2026-08-19")!, createdAt: Date(), pixelWidth: 1,
            pixelHeight: 1, fileSize: 1, format: .jpeg, fileState: .available, isCurrent: false
        )
    }
}

private actor ControlledSleeper: AsyncSleeping {
    private var active = 0
    private var maximumActive = 0
    private var calls = 0
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func sleep(for duration: Duration) async throws {
        calls += 1
        active += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelPendingSleeps() }
        }
    }

    func maximumActiveCount() -> Int { maximumActive }
    func callCount() -> Int { calls }

    private func cancelPendingSleeps() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(throwing: CancellationError()) }
    }
}

private actor CandidateSource: RotationCandidateProviding {
    let wallpapers: [Wallpaper]
    init(wallpapers: [Wallpaper]) { self.wallpapers = wallpapers }
    func candidates() async throws -> [Wallpaper] { wallpapers }
}

private actor RecordingApplier: RotationWallpaperApplying {
    private var count = 0
    func apply(wallpaper: Wallpaper) async throws { count += 1 }
    func applicationCount() -> Int { count }
}
