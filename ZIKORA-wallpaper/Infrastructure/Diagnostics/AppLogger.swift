import Foundation
import OSLog

nonisolated enum AppLogCategory: String, Sendable {
    case application
    case networking
    case persistence
    case fileStore
    case systemIntegration
}

nonisolated enum AppLogLevel: String, Sendable {
    case debug
    case information
    case warning
    case error
}

nonisolated enum AppLogEvent: String, Sendable {
    case operationStarted
    case operationSucceeded
    case operationFailed
    case requestStarted
    case requestRejected
    case stateRestored
    case systemActionFailed
    case inconsistencyDetected
}

nonisolated struct AppLogRecord: Equatable, Sendable {
    let category: AppLogCategory
    let level: AppLogLevel
    let event: AppLogEvent
    let errorCode: AppErrorCode?
    let redactedURL: String?

    init(
        category: AppLogCategory,
        level: AppLogLevel,
        event: AppLogEvent,
        errorCode: AppErrorCode? = nil,
        url: URL? = nil
    ) {
        self.category = category
        self.level = level
        self.event = event
        self.errorCode = errorCode
        self.redactedURL = url.map(URLRedactor.redact)
    }
}

nonisolated protocol AppLogging: Sendable {
    func log(_ record: AppLogRecord)
}

nonisolated struct NoOpAppLogger: AppLogging {
    func log(_ record: AppLogRecord) {}
}

nonisolated struct UnifiedAppLogger: AppLogging {
    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "cn.zhikezhui.ZIKORA-wallpaper") {
        self.subsystem = subsystem
    }

    func log(_ record: AppLogRecord) {
        let logger = Logger(subsystem: subsystem, category: record.category.rawValue)
        let event = record.event.rawValue
        let errorCode = record.errorCode?.rawValue ?? "none"
        let url = record.redactedURL ?? "none"
        let message = "event=\(event) error=\(errorCode) url=\(url)"

        switch record.level {
        case .debug:
            logger.debug("\(message, privacy: .private(mask: .hash))")
        case .information:
            logger.info("\(message, privacy: .private(mask: .hash))")
        case .warning:
            logger.warning("\(message, privacy: .private(mask: .hash))")
        case .error:
            logger.error("\(message, privacy: .private(mask: .hash))")
        }
    }
}
