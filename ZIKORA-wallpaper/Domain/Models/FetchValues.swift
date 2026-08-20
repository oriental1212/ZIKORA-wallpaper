import Foundation

nonisolated enum FetchTaskKind: String, CaseIterable, Codable, Sendable {
    case automaticDaily = "automatic_daily"
    case manualUpdate = "manual_update"
}

nonisolated enum DailyFetchStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case retryScheduled = "retry_scheduled"
    case success
    case failed
}
