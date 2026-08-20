import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct WallpaperCommandCenterTests {
    @Test("Update runs through the shared orchestrator and refreshes current state")
    func updateUsesSharedCommand() async throws {
        let repository = try InMemoryRepositoryStore(
            settings: UserSettings.defaults(id: UUID(), updatedAt: date())
        )
        let orchestrator = StubOrchestrator(
            result: FetchExecutionResult(
                taskKind: .manualUpdate,
                wallpaperID: nil,
                usedDefaultSource: false
            )
        )
        let center = makeCenter(repository: repository, orchestrator: orchestrator)

        await center.updateNow()

        #expect(await orchestrator.executionCount() == 1)
        #expect(center.isRunning == false)
        #expect(center.isUpdating == false)
        #expect(center.notice == nil)
    }

    @Test("Next wallpaper is local-only and never calls the fetch orchestrator")
    func nextWallpaperIsLocal() async throws {
        let first = makeWallpaper(id: 1, hash: "one", isCurrent: true)
        let second = makeWallpaper(id: 2, hash: "two", isCurrent: false)
        let repository = try InMemoryRepositoryStore(
            wallpapers: [first, second],
            settings: UserSettings.defaults(id: UUID(), updatedAt: date())
        )
        let orchestrator = StubOrchestrator(
            result: FetchExecutionResult(
                taskKind: .manualUpdate,
                wallpaperID: nil,
                usedDefaultSource: false
            )
        )
        let center = makeCenter(repository: repository, orchestrator: orchestrator)
        await center.refresh()

        await center.nextWallpaper()

        #expect(await orchestrator.executionCount() == 0)
        #expect(center.currentWallpaper?.id == second.id)
        #expect(center.notice == nil)
        #expect(try await repository.allWallpapers().filter(\.isCurrent).count == 1)
    }

    @Test("A failed update surfaces a user message and unlocks commands")
    func failedUpdatePublishesFailure() async throws {
        let repository = try InMemoryRepositoryStore()
        let orchestrator = StubOrchestrator(
            error: AppFailure(code: .networkUnavailable)
        )
        let center = makeCenter(repository: repository, orchestrator: orchestrator)

        await center.updateNow()

        #expect(center.notice?.message.title == .errorNetworkUnavailableTitle)
        #expect(center.isRunning == false)
        #expect(center.isUpdating == false)
    }

    private func makeCenter(
        repository: any RepositoryStore,
        orchestrator: any FetchOrchestrating
    ) -> WallpaperCommandCenter {
        WallpaperCommandCenter(
            orchestrator: orchestrator,
            repository: repository,
            setCurrentWallpaper: SetCurrentWallpaperUseCase(
                wallpapers: repository,
                desktopWallpaperSetter: StubDesktopSetter(successCount: 1)
            ),
            managedRootURL: URL(fileURLWithPath: "/tmp/zikora-command-center"),
            randomSelector: FixedRandomSelector(value: 0)
        )
    }

    private func makeWallpaper(id: UInt8, hash: String, isCurrent: Bool) -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)
            )),
            contentHash: hash,
            sourceID: nil,
            sourceNameSnapshot: "Source \(id)",
            relativePath: ManagedRelativePath(rawValue: "2026-08-19/\(id).png")!,
            downloadDay: LocalDay(rawValue: "2026-08-19")!,
            createdAt: date().addingTimeInterval(TimeInterval(id)),
            pixelWidth: 10,
            pixelHeight: 10,
            fileSize: 1,
            format: .png,
            fileState: .available,
            isCurrent: isCurrent
        )
    }

    private func date() -> Date {
        Date(timeIntervalSince1970: 1_787_000_000)
    }
}

private actor StubOrchestrator: FetchOrchestrating {
    private let result: FetchExecutionResult?
    private let error: AppFailure?
    private var executions = 0

    init(result: FetchExecutionResult) {
        self.result = result
        self.error = nil
    }

    init(error: AppFailure) {
        self.result = nil
        self.error = error
    }

    func run(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason
    ) async throws -> FetchExecutionResult {
        executions += 1
        if let error {
            throw error
        }
        return result!
    }

    func isRunning() -> Bool {
        false
    }

    func executionCount() -> Int {
        executions
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
