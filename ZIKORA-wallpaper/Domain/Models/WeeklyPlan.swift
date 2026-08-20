import Foundation

nonisolated struct WeeklyPlanSourceOption: Equatable, Sendable {
    let id: SourceID
    let name: String
}

nonisolated enum WeeklyPlanReferenceState: Equatable, Sendable {
    case unset
    case available(sourceID: SourceID, name: String)
    case disabled(sourceID: SourceID, name: String)
    case missing(sourceID: SourceID)
}

nonisolated struct WeeklyPlanRow: Equatable, Sendable {
    let weekday: Weekday
    let referenceState: WeeklyPlanReferenceState
    let isToday: Bool
}

nonisolated struct WeeklyPlanSnapshot: Equatable, Sendable {
    let schedule: WeeklySchedule
    let rows: [WeeklyPlanRow]
    let selectableSources: [WeeklyPlanSourceOption]
}

nonisolated enum WeeklyPlanError: Error, Equatable, Sendable {
    case sourceUnavailable(SourceID)
    case scheduleSaveFailed(previousSchedule: WeeklySchedule?)
}
