import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct AppFailureTests {
    @Test("Every error code maps to a localized message and recovery action", arguments: AppErrorCode.allCases)
    func everyCodeHasMessage(code: AppErrorCode) {
        let failure = AppFailure(code: code)
        let message = UserMessageCatalog.message(for: failure)

        #expect(!message.title.rawValue.isEmpty)
        #expect(!message.detail.rawValue.isEmpty)
        #expect(message.recoveryAction == failure.recoveryAction)
    }

    @Test("Callers may override the default recovery action")
    func recoveryOverride() {
        let failure = AppFailure(code: .networkUnavailable, recoveryAction: .openSettings)

        #expect(UserMessageCatalog.message(for: failure).recoveryAction == .openSettings)
    }
}
