import Foundation

nonisolated enum SourceResolutionReason: Equatable, Sendable {
    case plannedSource
    case noPlannedSource
    case plannedSourceUnavailable
    case plannedSourceFinalFailure
    case noCandidate
}

nonisolated struct SourceResolutionDecision: Equatable, Sendable {
    let actualSourceID: SourceID?
    let usedDefaultSource: Bool
    let reason: SourceResolutionReason

    var canFetch: Bool {
        actualSourceID != nil
    }
}

nonisolated enum DefaultSourceError: Error, Equatable, Sendable {
    case sourceUnavailable(SourceID)
    case scheduleSaveFailed(previousSchedule: WeeklySchedule?)
}
