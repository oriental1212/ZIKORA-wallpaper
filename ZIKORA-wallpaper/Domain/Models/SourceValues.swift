import Foundation

nonisolated enum SourceFetchStatus: String, CaseIterable, Codable, Sendable {
    case never
    case loading
    case success
    case offline
    case failed
}

nonisolated enum SourceHealthStatus: String, CaseIterable, Codable, Sendable {
    case disabled
    case unknown
    case healthy
    case offline
    case failing
    case warning

    static func evaluate(
        isEnabled: Bool,
        lastFetchStatus: SourceFetchStatus,
        consecutiveFailureDays: Int
    ) -> SourceHealthStatus {
        guard isEnabled else {
            return .disabled
        }
        guard consecutiveFailureDays < 3 else {
            return .warning
        }

        switch lastFetchStatus {
        case .never, .loading:
            return .unknown
        case .success:
            return .healthy
        case .offline:
            return .offline
        case .failed:
            return .failing
        }
    }
}
