import Foundation

nonisolated enum AppErrorCode: String, CaseIterable, Codable, Sendable {
    case invalidURL
    case networkUnavailable
    case requestTimedOut
    case invalidResponse
    case imageTooLarge
    case unsupportedImage
    case storageUnavailable
    case fileOperationFailed
    case persistenceFailed
    case wallpaperUpdateFailed
    case loginItemDenied
    case missingConfiguration
    case noWallpaperCandidate
    case operationCancelled
    case unknown
}

nonisolated enum RecoveryAction: String, Codable, Sendable {
    case retry
    case editSource
    case openSettings
    case configureSource
    case openLibrary
    case none
}

nonisolated struct AppFailure: Error, Equatable, Sendable {
    let code: AppErrorCode
    let recoveryAction: RecoveryAction

    init(code: AppErrorCode, recoveryAction: RecoveryAction? = nil) {
        self.code = code
        self.recoveryAction = recoveryAction ?? UserMessageCatalog.defaultRecoveryAction(for: code)
    }
}
