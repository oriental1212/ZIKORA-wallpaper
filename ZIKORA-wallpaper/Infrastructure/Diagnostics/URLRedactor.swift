import Foundation

nonisolated enum URLRedactor {
    static func redact(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme != nil,
              components.host != nil else {
            return "<redacted-url>"
        }

        components.user = nil
        components.password = nil
        components.fragment = nil
        if components.query != nil {
            components.query = "<redacted>"
        }

        return components.string ?? "<redacted-url>"
    }
}
