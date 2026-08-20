import Foundation

nonisolated struct ResolveSourceUseCase: Sendable {
    static func resolve(
        plannedSourceID: SourceID?,
        defaultSourceID: SourceID?,
        sources: [WallpaperSource],
        plannedAttemptFinalFailure: Bool
    ) -> SourceResolutionDecision {
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let plannedIsAvailable = plannedSourceID.map {
            sourcesByID[$0]?.isEnabled == true
        } == true

        if plannedIsAvailable && !plannedAttemptFinalFailure {
            return SourceResolutionDecision(
                actualSourceID: plannedSourceID,
                usedDefaultSource: false,
                reason: .plannedSource
            )
        }

        let fallbackReason: SourceResolutionReason
        if plannedSourceID == nil {
            fallbackReason = .noPlannedSource
        } else if plannedAttemptFinalFailure && plannedIsAvailable {
            fallbackReason = .plannedSourceFinalFailure
        } else {
            fallbackReason = .plannedSourceUnavailable
        }

        if let defaultSourceID,
           defaultSourceID != plannedSourceID,
           sourcesByID[defaultSourceID]?.isEnabled == true {
            return SourceResolutionDecision(
                actualSourceID: defaultSourceID,
                usedDefaultSource: true,
                reason: fallbackReason
            )
        }

        return SourceResolutionDecision(
            actualSourceID: nil,
            usedDefaultSource: false,
            reason: .noCandidate
        )
    }

    func apply(
        to record: DailyFetchRecord,
        plannedSourceID: SourceID?,
        defaultSourceID: SourceID?,
        sources: [WallpaperSource],
        plannedAttemptFinalFailure: Bool
    ) -> DailyFetchRecord {
        let decision = Self.resolve(
            plannedSourceID: plannedSourceID,
            defaultSourceID: defaultSourceID,
            sources: sources,
            plannedAttemptFinalFailure: plannedAttemptFinalFailure
        )
        var updated = record
        updated.actualSourceID = decision.actualSourceID
        updated.usedDefaultSource = decision.usedDefaultSource
        return updated
    }
}

nonisolated struct UpdateDefaultSourceUseCase: Sendable {
    private let sources: any SourceRepository
    private let schedules: any ScheduleRepository
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerating

    init(
        sources: any SourceRepository,
        schedules: any ScheduleRepository,
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.sources = sources
        self.schedules = schedules
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    func execute(sourceID: SourceID?) async throws -> WeeklySchedule {
        if let sourceID {
            guard let source = try await sources.source(id: sourceID), source.isEnabled else {
                throw DefaultSourceError.sourceUnavailable(sourceID)
            }
        }

        let previous = try await schedules.loadSchedule()
        if let previous, previous.defaultSourceID == sourceID {
            return previous
        }

        let now = await clock.now()
        var updated: WeeklySchedule
        if let previous {
            updated = previous
        } else {
            updated = WeeklySchedule(
                id: await uuidGenerator.makeUUID(),
                mondaySourceID: nil,
                tuesdaySourceID: nil,
                wednesdaySourceID: nil,
                thursdaySourceID: nil,
                fridaySourceID: nil,
                saturdaySourceID: nil,
                sundaySourceID: nil,
                defaultSourceID: nil,
                updatedAt: now
            )
        }
        updated.defaultSourceID = sourceID
        updated.updatedAt = now

        do {
            try await schedules.save(updated)
            return updated
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DefaultSourceError.scheduleSaveFailed(previousSchedule: previous)
        }
    }
}
