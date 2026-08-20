import Foundation

nonisolated protocol DomainIdentifier: Codable, Hashable, RawRepresentable, Sendable
where RawValue == UUID {}

nonisolated struct SourceID: DomainIdentifier {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

nonisolated struct WallpaperID: DomainIdentifier {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

nonisolated struct DailyFetchRecordID: DomainIdentifier {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
