import Foundation
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct SetCurrentWallpaperUseCaseTests {
    enum Backend: String, CaseIterable, Sendable {
        case inMemory
        case swiftData
    }

    @Test("Full display success commits exactly one current wallpaper", arguments: Backend.allCases)
    func fullSuccess(backend: Backend) async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(backend, wallpapers: [fixture.old, fixture.new])
        let setter = RecordingDesktopWallpaperSetter(results: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: true),
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "external"), succeeded: true),
        ])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        let outcome = try await useCase.execute(
            wallpaperID: fixture.new.id,
            fileURL: fixture.fileURL
        )

        #expect(outcome == .applied(
            wallpaperID: fixture.new.id,
            succeededDisplayCount: 2
        ))
        #expect(try await currentIDs(in: store) == [fixture.new.id])
        #expect(await setter.receivedURLs() == [fixture.fileURL])
    }

    @Test("All display failures retain the previous current wallpaper", arguments: Backend.allCases)
    func allDisplaysFail(backend: Backend) async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(backend, wallpapers: [fixture.old, fixture.new])
        let setter = RecordingDesktopWallpaperSetter(results: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: false),
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "external"), succeeded: false),
        ])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        await #expect(throws: CurrentWallpaperUpdateError.allDisplaysFailed(
            failedDisplayCount: 2
        )) {
            try await useCase.execute(
                wallpaperID: fixture.new.id,
                fileURL: fixture.fileURL
            )
        }
        #expect(try await currentIDs(in: store) == [fixture.old.id])
    }

    @Test("Partial display success commits current and reports warning counts", arguments: Backend.allCases)
    func partialDisplaySuccess(backend: Backend) async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(backend, wallpapers: [fixture.old, fixture.new])
        let setter = RecordingDesktopWallpaperSetter(results: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: true),
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "external"), succeeded: false),
        ])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        let outcome = try await useCase.execute(
            wallpaperID: fixture.new.id,
            fileURL: fixture.fileURL
        )

        #expect(outcome == .appliedWithWarning(
            wallpaperID: fixture.new.id,
            succeededDisplayCount: 1,
            failedDisplayCount: 1
        ))
        #expect(try await currentIDs(in: store) == [fixture.new.id])
    }

    @Test("Selecting the current wallpaper is idempotent and repairs duplicate flags", arguments: Backend.allCases)
    func sameWallpaper(backend: Backend) async throws {
        let fixture = try makeFixture()
        var duplicateCurrent = fixture.new
        duplicateCurrent.isCurrent = true
        let store = try await makeStore(
            backend,
            wallpapers: [fixture.old, duplicateCurrent]
        )
        let setter = RecordingDesktopWallpaperSetter(results: [])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        let outcome = try await useCase.execute(
            wallpaperID: duplicateCurrent.id,
            fileURL: fixture.fileURL
        )

        #expect(outcome == .unchanged(wallpaperID: duplicateCurrent.id))
        #expect(await setter.receivedURLs().isEmpty)
        #expect(try await currentIDs(in: store) == [duplicateCurrent.id])
    }

    @Test("A successful first application creates the only current marker", arguments: Backend.allCases)
    func noPreviousCurrent(backend: Backend) async throws {
        let fixture = try makeFixture()
        var candidate = fixture.new
        candidate.isCurrent = false
        let store = try await makeStore(backend, wallpapers: [candidate])
        let setter = RecordingDesktopWallpaperSetter(results: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: true),
        ])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        _ = try await useCase.execute(
            wallpaperID: candidate.id,
            fileURL: fixture.fileURL
        )
        #expect(try await currentIDs(in: store) == [candidate.id])
    }

    @Test("No connected display is not treated as system success", arguments: Backend.allCases)
    func noDisplays(backend: Backend) async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(backend, wallpapers: [fixture.old, fixture.new])
        let setter = RecordingDesktopWallpaperSetter(results: [])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )

        await #expect(throws: CurrentWallpaperUpdateError.noDisplaysAvailable) {
            try await useCase.execute(
                wallpaperID: fixture.new.id,
                fileURL: fixture.fileURL
            )
        }
        #expect(try await currentIDs(in: store) == [fixture.old.id])
    }

    @Test("Cancellation after the system call starts does not commit current")
    func cancellationRetainsCurrent() async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(.inMemory, wallpapers: [fixture.old, fixture.new])
        let setter = ManuallyCompletingDesktopWallpaperSetter()
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: store,
            desktopWallpaperSetter: setter
        )
        let task = Task {
            try await useCase.execute(
                wallpaperID: fixture.new.id,
                fileURL: fixture.fileURL
            )
        }

        await setter.waitUntilStarted()
        task.cancel()
        await setter.complete(with: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: true),
        ])

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(try await currentIDs(in: store) == [fixture.old.id])
    }

    @Test("A failed repository current transaction retains the old marker", arguments: Backend.allCases)
    func repositoryTransactionFailure(backend: Backend) async throws {
        let fixture = try makeFixture()
        let store = try await makeStore(backend, wallpapers: [fixture.old])
        let missingID = WallpaperID(rawValue: fixedUUID(99))

        await #expect(throws: RepositoryError.notFound(entity: .wallpaper)) {
            try await store.markCurrent(id: missingID)
        }
        #expect(try await currentIDs(in: store) == [fixture.old.id])
    }

    @Test("A persistence failure after system success leaves the old database current")
    func persistenceFailureAfterSystemSuccess() async throws {
        let fixture = try makeFixture()
        let baseStore = try await makeStore(
            .inMemory,
            wallpapers: [fixture.old, fixture.new]
        )
        let failingStore = FailingCurrentWallpaperRepository(base: baseStore)
        let setter = RecordingDesktopWallpaperSetter(results: [
            DisplayWallpaperResult(displayID: DisplayID(rawValue: "main"), succeeded: true),
        ])
        let useCase = SetCurrentWallpaperUseCase(
            wallpapers: failingStore,
            desktopWallpaperSetter: setter
        )

        await #expect(throws: CurrentWallpaperUpdateError.repository(
            .persistenceFailed(entity: .wallpaper, operation: .transaction)
        )) {
            try await useCase.execute(
                wallpaperID: fixture.new.id,
                fileURL: fixture.fileURL
            )
        }
        #expect(try await currentIDs(in: baseStore) == [fixture.old.id])
    }

    private struct Fixture {
        let old: Wallpaper
        let new: Wallpaper
        let fileURL: URL
    }

    private func makeFixture() throws -> Fixture {
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let oldPath = try #require(ManagedRelativePath(rawValue: "Wallpapers/old.png"))
        let newPath = try #require(ManagedRelativePath(rawValue: "Wallpapers/new.png"))
        let oldDate = Date(timeIntervalSince1970: 1_787_000_000)
        let newDate = oldDate.addingTimeInterval(60)
        let old = Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(1)),
            contentHash: "old-hash",
            sourceID: nil,
            sourceNameSnapshot: "Old",
            relativePath: oldPath,
            downloadDay: day,
            createdAt: oldDate,
            pixelWidth: 100,
            pixelHeight: 100,
            fileSize: 100,
            format: .png,
            fileState: .available,
            isCurrent: true
        )
        let new = Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(2)),
            contentHash: "new-hash",
            sourceID: nil,
            sourceNameSnapshot: "New",
            relativePath: newPath,
            downloadDay: day,
            createdAt: newDate,
            pixelWidth: 200,
            pixelHeight: 100,
            fileSize: 200,
            format: .png,
            fileState: .available,
            isCurrent: false
        )
        return Fixture(
            old: old,
            new: new,
            fileURL: URL(fileURLWithPath: "/tmp/zikora-current-wallpaper.png")
        )
    }

    private func makeStore(
        _ backend: Backend,
        wallpapers: [Wallpaper]
    ) async throws -> any WallpaperRepository {
        let store: any RepositoryStore
        switch backend {
        case .inMemory:
            store = try InMemoryRepositoryStore()
        case .swiftData:
            store = SwiftDataRepositoryStore(
                modelContainer: try PersistenceContainerFactory.makeInMemoryStore()
            )
        }
        for wallpaper in wallpapers {
            try await store.save(wallpaper)
        }
        return store
    }

    private func currentIDs(in store: any WallpaperRepository) async throws -> [WallpaperID] {
        try await store.allWallpapers()
            .filter(\.isCurrent)
            .map(\.id)
    }

    nonisolated private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private actor RecordingDesktopWallpaperSetter: DesktopWallpaperSetting {
    private let results: [DisplayWallpaperResult]
    private var urls: [URL] = []

    init(results: [DisplayWallpaperResult]) {
        self.results = results
    }

    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult] {
        urls.append(fileURL)
        return results
    }

    func receivedURLs() -> [URL] {
        urls
    }
}

private actor ManuallyCompletingDesktopWallpaperSetter: DesktopWallpaperSetting {
    private var hasStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<[DisplayWallpaperResult], Never>?

    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult] {
        hasStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()

        return await withCheckedContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !hasStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func complete(with results: [DisplayWallpaperResult]) {
        resultContinuation?.resume(returning: results)
        resultContinuation = nil
    }
}

private actor FailingCurrentWallpaperRepository: WallpaperRepository {
    private let base: any WallpaperRepository

    init(base: any WallpaperRepository) {
        self.base = base
    }

    func allWallpapers() async throws -> [Wallpaper] {
        try await base.allWallpapers()
    }

    func wallpaper(id: WallpaperID) async throws -> Wallpaper? {
        try await base.wallpaper(id: id)
    }

    func wallpaper(contentHash: String) async throws -> Wallpaper? {
        try await base.wallpaper(contentHash: contentHash)
    }

    func save(_ wallpaper: Wallpaper) async throws {
        try await base.save(wallpaper)
    }

    func delete(id: WallpaperID) async throws {
        try await base.delete(id: id)
    }

    func markFileState(id: WallpaperID, state: WallpaperFileState) async throws {
        try await base.markFileState(id: id, state: state)
    }

    func markCurrent(id: WallpaperID) async throws {
        throw RepositoryError.persistenceFailed(entity: .wallpaper, operation: .transaction)
    }
}
