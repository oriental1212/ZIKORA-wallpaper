import Foundation

nonisolated struct WallpaperSource: Codable, Equatable, Sendable {
    let id: SourceID
    var name: String
    var url: URL
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date
    var lastFetchAt: Date?
    var lastFetchStatus: SourceFetchStatus
    var lastErrorCode: AppErrorCode?
    var lastErrorMessage: String?
    var consecutiveFailureDays: Int

    var healthStatus: SourceHealthStatus {
        SourceHealthStatus.evaluate(
            isEnabled: isEnabled,
            lastFetchStatus: lastFetchStatus,
            consecutiveFailureDays: consecutiveFailureDays
        )
    }
}
