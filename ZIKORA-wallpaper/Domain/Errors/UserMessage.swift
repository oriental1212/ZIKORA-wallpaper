import Foundation

nonisolated enum UserMessageKey: String, CaseIterable, Sendable {
    case errorInvalidURLTitle = "error.invalid-url.title"
    case errorInvalidURLDetail = "error.invalid-url.detail"
    case errorNetworkUnavailableTitle = "error.network-unavailable.title"
    case errorNetworkUnavailableDetail = "error.network-unavailable.detail"
    case errorRequestTimedOutTitle = "error.request-timeout.title"
    case errorRequestTimedOutDetail = "error.request-timeout.detail"
    case errorInvalidResponseTitle = "error.invalid-response.title"
    case errorInvalidResponseDetail = "error.invalid-response.detail"
    case errorImageTooLargeTitle = "error.image-too-large.title"
    case errorImageTooLargeDetail = "error.image-too-large.detail"
    case errorUnsupportedImageTitle = "error.unsupported-image.title"
    case errorUnsupportedImageDetail = "error.unsupported-image.detail"
    case errorStorageUnavailableTitle = "error.storage-unavailable.title"
    case errorStorageUnavailableDetail = "error.storage-unavailable.detail"
    case errorFileOperationTitle = "error.file-operation.title"
    case errorFileOperationDetail = "error.file-operation.detail"
    case errorPersistenceTitle = "error.persistence.title"
    case errorPersistenceDetail = "error.persistence.detail"
    case errorWallpaperUpdateTitle = "error.wallpaper-update.title"
    case errorWallpaperUpdateDetail = "error.wallpaper-update.detail"
    case errorLoginItemTitle = "error.login-item.title"
    case errorLoginItemDetail = "error.login-item.detail"
    case errorMissingConfigurationTitle = "error.missing-configuration.title"
    case errorMissingConfigurationDetail = "error.missing-configuration.detail"
    case errorNoCandidateTitle = "error.no-candidate.title"
    case errorNoCandidateDetail = "error.no-candidate.detail"
    case errorCancelledTitle = "error.cancelled.title"
    case errorCancelledDetail = "error.cancelled.detail"
    case errorUnknownTitle = "error.unknown.title"
    case errorUnknownDetail = "error.unknown.detail"
}

nonisolated struct UserMessage: Equatable, Sendable {
    let title: UserMessageKey
    let detail: UserMessageKey
    let recoveryAction: RecoveryAction
}

nonisolated enum OperationNoticeTone: String, Sendable {
    case information
    case success
    case warning
    case failure
}

nonisolated struct OperationNotice: Equatable, Sendable {
    let tone: OperationNoticeTone
    let message: UserMessage
}

nonisolated enum UserMessageCatalog {
    static func message(for failure: AppFailure) -> UserMessage {
        let keys = keys(for: failure.code)
        return UserMessage(
            title: keys.title,
            detail: keys.detail,
            recoveryAction: failure.recoveryAction
        )
    }

    static func defaultRecoveryAction(for code: AppErrorCode) -> RecoveryAction {
        switch code {
        case .invalidURL, .invalidResponse, .imageTooLarge, .unsupportedImage:
            .editSource
        case .networkUnavailable, .requestTimedOut, .fileOperationFailed,
             .persistenceFailed, .wallpaperUpdateFailed, .unknown:
            .retry
        case .storageUnavailable, .loginItemDenied:
            .openSettings
        case .missingConfiguration:
            .configureSource
        case .noWallpaperCandidate:
            .openLibrary
        case .operationCancelled:
            .none
        }
    }

    private static func keys(for code: AppErrorCode) -> (title: UserMessageKey, detail: UserMessageKey) {
        switch code {
        case .invalidURL:
            (.errorInvalidURLTitle, .errorInvalidURLDetail)
        case .networkUnavailable:
            (.errorNetworkUnavailableTitle, .errorNetworkUnavailableDetail)
        case .requestTimedOut:
            (.errorRequestTimedOutTitle, .errorRequestTimedOutDetail)
        case .invalidResponse:
            (.errorInvalidResponseTitle, .errorInvalidResponseDetail)
        case .imageTooLarge:
            (.errorImageTooLargeTitle, .errorImageTooLargeDetail)
        case .unsupportedImage:
            (.errorUnsupportedImageTitle, .errorUnsupportedImageDetail)
        case .storageUnavailable:
            (.errorStorageUnavailableTitle, .errorStorageUnavailableDetail)
        case .fileOperationFailed:
            (.errorFileOperationTitle, .errorFileOperationDetail)
        case .persistenceFailed:
            (.errorPersistenceTitle, .errorPersistenceDetail)
        case .wallpaperUpdateFailed:
            (.errorWallpaperUpdateTitle, .errorWallpaperUpdateDetail)
        case .loginItemDenied:
            (.errorLoginItemTitle, .errorLoginItemDetail)
        case .missingConfiguration:
            (.errorMissingConfigurationTitle, .errorMissingConfigurationDetail)
        case .noWallpaperCandidate:
            (.errorNoCandidateTitle, .errorNoCandidateDetail)
        case .operationCancelled:
            (.errorCancelledTitle, .errorCancelledDetail)
        case .unknown:
            (.errorUnknownTitle, .errorUnknownDetail)
        }
    }
}
