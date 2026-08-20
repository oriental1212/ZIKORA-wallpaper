import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct DefaultResolutionTests {
    @Test("A healthy planned source wins without using the default")
    func plannedSourceWins() throws {
        let planned = try source(id: 1, name: "Planned", enabled: true)
        let fallback = try source(id: 2, name: "Fallback", enabled: true)
        let result = ResolveSourceUseCase.resolve(
            plannedSourceID: planned.id,
            defaultSourceID: fallback.id,
            sources: [planned, fallback],
            plannedAttemptFinalFailure: false
        )
        #expect(result == SourceResolutionDecision(
            actualSourceID: planned.id,
            usedDefaultSource: false,
            reason: .plannedSource
        ))
    }

    @Test("Missing, disabled, and final-failed planned sources use an enabled default")
    func fallbackReasons() throws {
        let planned = try source(id: 1, name: "Planned", enabled: true)
        let disabled = try source(id: 2, name: "Disabled", enabled: false)
        let fallback = try source(id: 3, name: "Fallback", enabled: true)

        let missing = ResolveSourceUseCase.resolve(
            plannedSourceID: SourceID(rawValue: fixedUUID(9)),
            defaultSourceID: fallback.id,
            sources: [planned, fallback],
            plannedAttemptFinalFailure: false
        )
        #expect(missing.actualSourceID == fallback.id)
        #expect(missing.usedDefaultSource)
        #expect(missing.reason == .plannedSourceUnavailable)

        let stopped = ResolveSourceUseCase.resolve(
            plannedSourceID: disabled.id,
            defaultSourceID: fallback.id,
            sources: [disabled, fallback],
            plannedAttemptFinalFailure: false
        )
        #expect(stopped.actualSourceID == fallback.id)
        #expect(stopped.usedDefaultSource)
        #expect(stopped.reason == .plannedSourceUnavailable)

        let finalFailure = ResolveSourceUseCase.resolve(
            plannedSourceID: planned.id,
            defaultSourceID: fallback.id,
            sources: [planned, fallback],
            plannedAttemptFinalFailure: true
        )
        #expect(finalFailure.actualSourceID == fallback.id)
        #expect(finalFailure.usedDefaultSource)
        #expect(finalFailure.reason == .plannedSourceFinalFailure)
    }

    @Test("A same-source default never creates a second attempt")
    func sameSourceDoesNotRetry() throws {
        let source = try source(id: 1, name: "Same", enabled: true)
        let result = ResolveSourceUseCase.resolve(
            plannedSourceID: source.id,
            defaultSourceID: source.id,
            sources: [source],
            plannedAttemptFinalFailure: true
        )
        #expect(result == SourceResolutionDecision(
            actualSourceID: nil,
            usedDefaultSource: false,
            reason: .noCandidate
        ))
    }

    @Test("No planned source can use the default once, with no recursive fallback")
    func noPlanUsesDefaultOnce() throws {
        let fallback = try source(id: 2, name: "Fallback", enabled: true)
        let result = ResolveSourceUseCase.resolve(
            plannedSourceID: nil,
            defaultSourceID: fallback.id,
            sources: [fallback],
            plannedAttemptFinalFailure: true
        )
        #expect(result.actualSourceID == fallback.id)
        #expect(result.usedDefaultSource)
        #expect(result.reason == .noPlannedSource)
    }

    @Test("Default source selection accepts only enabled sources and supports clearing")
    func updatesDefaultSource() async throws {
        let store = try InMemoryRepositoryStore()
        let enabled = try source(id: 30, name: "Enabled", enabled: true)
        let disabled = try source(id: 31, name: "Disabled", enabled: false)
        try await store.save(enabled)
        try await store.save(disabled)
        let useCase = UpdateDefaultSourceUseCase(
            sources: store,
            schedules: store,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1000)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(32))
        )

        let selected = try await useCase.execute(sourceID: enabled.id)
        #expect(selected.defaultSourceID == enabled.id)
        await #expect(throws: DefaultSourceError.sourceUnavailable(disabled.id)) {
            try await useCase.execute(sourceID: disabled.id)
        }
        let cleared = try await useCase.execute(sourceID: nil)
        #expect(cleared.defaultSourceID == nil)
    }

    @Test("Resolution is recorded as actual source and usedDefault without mutating the original")
    func appliesToRecord() throws {
        let planned = try source(id: 1, name: "Planned", enabled: false)
        let fallback = try source(id: 2, name: "Fallback", enabled: true)
        let record = DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: fixedUUID(20)),
            taskKey: "2026-08-19|automatic_daily",
            localDay: try #require(LocalDay(rawValue: "2026-08-19")),
            taskKind: .automaticDaily,
            plannedSourceID: planned.id,
            actualSourceID: nil,
            status: .pending,
            automaticAttemptCount: 0,
            usedDefaultSource: false,
            wallpaperID: nil,
            lastAttemptAt: nil,
            nextRetryAt: nil,
            lastErrorCode: nil
        )
        let resolved = ResolveSourceUseCase().apply(
            to: record,
            plannedSourceID: record.plannedSourceID,
            defaultSourceID: fallback.id,
            sources: [planned, fallback],
            plannedAttemptFinalFailure: false
        )
        #expect(record.actualSourceID == nil)
        #expect(resolved.actualSourceID == fallback.id)
        #expect(resolved.usedDefaultSource)
    }

    private func source(id: UInt8, name: String, enabled: Bool) throws -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: fixedUUID(id)),
            name: name,
            url: try #require(URL(string: "https://example.test/\(id).png")),
            isEnabled: enabled,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id)),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
