import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct DiagnosticsTests {
    @Test("URL diagnostics remove credentials, query values, and fragments")
    func urlRedaction() throws {
        let url = try #require(URL(string: "https://user:secret@example.com/image/today.jpg?token=private&size=large#preview"))
        let redacted = URLRedactor.redact(url)

        #expect(redacted.contains("https://example.com/image/today.jpg"))
        #expect(redacted.contains("%3Credacted%3E") || redacted.contains("<redacted>"))
        #expect(!redacted.contains("secret"))
        #expect(!redacted.contains("private"))
        #expect(!redacted.contains("large"))
        #expect(!redacted.contains("preview"))
    }

    @Test("Log records retain only structured identifiers and a redacted URL")
    func structuredLogRecord() throws {
        let url = try #require(URL(string: "https://images.example.test/a.png?signature=sensitive"))
        let record = AppLogRecord(
            category: .networking,
            level: .error,
            event: .requestRejected,
            errorCode: .invalidResponse,
            url: url
        )

        #expect(record.errorCode == .invalidResponse)
        #expect(record.redactedURL?.contains("sensitive") == false)
    }
}
