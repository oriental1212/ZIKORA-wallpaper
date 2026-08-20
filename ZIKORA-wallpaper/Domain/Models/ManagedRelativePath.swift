import Foundation

nonisolated struct ManagedRelativePath: Codable, Hashable, RawRepresentable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        guard !rawValue.isEmpty,
              !rawValue.hasPrefix("/"),
              !rawValue.contains("\\"),
              !rawValue.contains("\0") else {
            return nil
        }

        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let persistedValue = try container.decode(String.self)
        guard let path = ManagedRelativePath(rawValue: persistedValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ManagedRelativePath must remain inside the managed root"
            )
        }

        self = path
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
