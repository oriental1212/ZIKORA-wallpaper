import Foundation

nonisolated enum SourceManagementError: Error, Equatable, Sendable {
    case inputNotReady
    case invalidFailureStatus
}

nonisolated struct SourceDeletionImpact: Equatable, Sendable {
    let sourceID: SourceID
    let sourceName: String
    let affectedWeekdays: [Weekday]
    let wasDefaultSource: Bool
}

nonisolated enum SourceHealthEvent: Equatable, Sendable {
    case requestStarted(at: Date)
    case requestFailed(
        at: Date,
        status: SourceFetchStatus,
        errorCode: AppErrorCode,
        redactedMessage: String?
    )
    case dailyFailureSettled(
        at: Date,
        status: SourceFetchStatus,
        errorCode: AppErrorCode,
        redactedMessage: String?
    )
    case requestSucceeded(at: Date)
}
