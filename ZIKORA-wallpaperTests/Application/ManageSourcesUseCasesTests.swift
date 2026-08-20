import Foundation
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct ManageSourcesUseCasesTests {
    enum Backend: String, CaseIterable, Sendable {
        case inMemory
        case swiftData
    }

    @Test("Create, edit, and list return persisted sources including disabled entries", arguments: Backend.allCases)
    func createEditAndList(backend: Backend) async throws {
        let store = try makeStore(backend)
        let createdAt = date(100)
        let sourceID = SourceID(rawValue: fixedUUID(1))
        let creator = SaveSourceUseCase(
            sources: store,
            clock: FixedClock(date: createdAt),
            uuidGenerator: FixedUUIDGenerator(value: sourceID.rawValue)
        )
        let createInput = SourceFormInput(
            name: "  Daily  ",
            urlText: "HTTPS://EXAMPLE.TEST/a.png",
            isEnabled: false
        )
        let created = try await creator.execute(
            input: createInput,
            context: .create,
            connectionProof: try proof(for: createInput)
        )

        #expect(created.id == sourceID)
        #expect(created.name == "Daily")
        #expect(created.url.absoluteString == "https://example.test/a.png")
        #expect(!created.isEnabled)
        #expect(created.lastFetchStatus == .never)

        let editedAt = date(200)
        let editor = SaveSourceUseCase(
            sources: store,
            clock: FixedClock(date: editedAt)
        )
        let editInput = SourceFormInput(
            name: "Renamed",
            urlText: "https://example.test/b.png",
            isEnabled: true
        )
        let edited = try await editor.execute(
            input: editInput,
            context: .edit(sourceID: sourceID, originalURL: created.url),
            connectionProof: try proof(for: editInput)
        )

        #expect(edited.name == "Renamed")
        #expect(edited.createdAt == createdAt)
        #expect(edited.updatedAt == editedAt)
        #expect(try await ListSourcesUseCase(sources: store).execute() == [edited])
    }

    @Test("Save rejects a decision that has not passed validation")
    func saveGate() async throws {
        let store = try InMemoryRepositoryStore()
        await #expect(throws: SourceManagementError.inputNotReady) {
            try await SaveSourceUseCase(sources: store).execute(
                input: SourceFormInput(name: "", urlText: "file:///tmp/a", isEnabled: true),
                context: .create,
                connectionProof: nil
            )
        }
        #expect(try await store.allSources().isEmpty)
    }

    @Test("Disable and re-enable preserve schedule references across a store reopen")
    func enablementPersistsWithoutChangingPlan() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "zikora-p03-source-toggle-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let storeURL = rootURL.appendingPathComponent("ZIKORA.store")
        let source = try makeSource(id: 2, name: "Toggle")
        let schedule = makeSchedule(sourceID: source.id, updatedAt: date(10))

        do {
            let container = try PersistenceContainerFactory.makeStore(at: storeURL)
            let store = SwiftDataRepositoryStore(modelContainer: container)
            try await store.save(source)
            try await store.save(schedule)
            let disabled = try await SetSourceEnabledUseCase(
                sources: store,
                clock: FixedClock(date: date(20))
            ).execute(sourceID: source.id, isEnabled: false)
            #expect(disabled.healthStatus == .disabled)
            #expect(try await store.loadSchedule() == schedule)
        }

        let reopenedContainer = try PersistenceContainerFactory.makeStore(at: storeURL)
        let reopenedStore = SwiftDataRepositoryStore(modelContainer: reopenedContainer)
        #expect(try await reopenedStore.source(id: source.id)?.isEnabled == false)
        #expect(try await reopenedStore.loadSchedule() == schedule)

        let enabled = try await SetSourceEnabledUseCase(
            sources: reopenedStore,
            clock: FixedClock(date: date(30))
        ).execute(sourceID: source.id, isEnabled: true)
        #expect(enabled.isEnabled)
        #expect(try await reopenedStore.loadSchedule() == schedule)
    }

    @Test("Delete reports impact, clears plan and default, and preserves wallpaper history", arguments: Backend.allCases)
    func deleteSource(backend: Backend) async throws {
        let store = try makeStore(backend)
        let source = try makeSource(id: 3, name: "Historical Source")
        let schedule = WeeklySchedule(
            id: fixedUUID(30),
            mondaySourceID: source.id,
            tuesdaySourceID: nil,
            wednesdaySourceID: source.id,
            thursdaySourceID: nil,
            fridaySourceID: nil,
            saturdaySourceID: nil,
            sundaySourceID: nil,
            defaultSourceID: source.id,
            updatedAt: date(10)
        )
        let wallpaper = try makeWallpaper(source: source)
        try await store.save(source)
        try await store.save(schedule)
        try await store.save(wallpaper)
        let useCase = DeleteSourceUseCase(
            repository: store,
            clock: FixedClock(date: date(40))
        )

        let expectedImpact = SourceDeletionImpact(
            sourceID: source.id,
            sourceName: source.name,
            affectedWeekdays: [.monday, .wednesday],
            wasDefaultSource: true
        )
        #expect(try await useCase.preview(sourceID: source.id) == expectedImpact)
        #expect(try await useCase.execute(sourceID: source.id) == expectedImpact)

        #expect(try await store.source(id: source.id) == nil)
        let cleanedSchedule = try #require(try await store.loadSchedule())
        #expect(cleanedSchedule.mondaySourceID == nil)
        #expect(cleanedSchedule.wednesdaySourceID == nil)
        #expect(cleanedSchedule.defaultSourceID == nil)
        #expect(cleanedSchedule.updatedAt == date(40))
        let history = try #require(try await store.wallpaper(id: wallpaper.id))
        #expect(history.sourceID == nil)
        #expect(history.sourceNameSnapshot == "Historical Source")
    }

    @Test("Only daily settlement increments failures; success resets warning state", arguments: Backend.allCases)
    func sourceHealth(backend: Backend) async throws {
        let store = try makeStore(backend)
        let source = try makeSource(id: 4, name: "Health")
        try await store.save(source)
        let useCase = UpdateSourceHealthUseCase(sources: store)

        let transient = try await useCase.execute(
            sourceID: source.id,
            event: .requestFailed(
                at: date(10),
                status: .offline,
                errorCode: .networkUnavailable,
                redactedMessage: "Network unavailable"
            )
        )
        #expect(transient.consecutiveFailureDays == 0)
        #expect(transient.healthStatus == .offline)

        for day in 1...3 {
            _ = try await useCase.execute(
                sourceID: source.id,
                event: .dailyFailureSettled(
                    at: date(10 + day),
                    status: .failed,
                    errorCode: .requestTimedOut,
                    redactedMessage: "Request timed out"
                )
            )
        }
        let warning = try #require(try await store.source(id: source.id))
        #expect(warning.consecutiveFailureDays == 3)
        #expect(warning.healthStatus == .warning)
        #expect(warning.isEnabled)

        let recovered = try await useCase.execute(
            sourceID: source.id,
            event: .requestSucceeded(at: date(20))
        )
        #expect(recovered.consecutiveFailureDays == 0)
        #expect(recovered.healthStatus == .healthy)
        #expect(recovered.lastErrorCode == nil)
        #expect(recovered.lastErrorMessage == nil)
    }

    private func proof(for input: SourceFormInput) throws -> SourceConnectionTestProof {
        let validation = EvaluateSourceInputUseCase.validate(input)
        let input = try #require(validation.input)
        return SourceConnectionTestProof(
            inputFingerprint: input.fingerprint,
            testedAt: date(1)
        )
    }

    private func makeStore(_ backend: Backend) throws -> any RepositoryStore {
        switch backend {
        case .inMemory:
            try InMemoryRepositoryStore()
        case .swiftData:
            SwiftDataRepositoryStore(
                modelContainer: try PersistenceContainerFactory.makeInMemoryStore()
            )
        }
    }

    private func makeSource(id: UInt8, name: String) throws -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: fixedUUID(id)),
            name: name,
            url: try #require(URL(string: "https://example.test/\(id).png")),
            isEnabled: true,
            createdAt: date(1),
            updatedAt: date(1),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }

    private func makeSchedule(sourceID: SourceID, updatedAt: Date) -> WeeklySchedule {
        WeeklySchedule(
            id: fixedUUID(20),
            mondaySourceID: sourceID,
            tuesdaySourceID: nil,
            wednesdaySourceID: nil,
            thursdaySourceID: nil,
            fridaySourceID: nil,
            saturdaySourceID: nil,
            sundaySourceID: nil,
            defaultSourceID: sourceID,
            updatedAt: updatedAt
        )
    }

    private func makeWallpaper(source: WallpaperSource) throws -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: fixedUUID(40)),
            contentHash: "historical-hash",
            sourceID: source.id,
            sourceNameSnapshot: source.name,
            relativePath: try #require(ManagedRelativePath(rawValue: "Wallpapers/history.png")),
            downloadDay: try #require(LocalDay(rawValue: "2026-08-19")),
            createdAt: date(5),
            pixelWidth: 100,
            pixelHeight: 100,
            fileSize: 100,
            format: .png,
            fileState: .available,
            isCurrent: false
        )
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_787_000_000 + TimeInterval(offset))
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
