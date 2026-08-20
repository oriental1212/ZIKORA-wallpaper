import Foundation

nonisolated struct WeeklySchedule: Codable, Equatable, Sendable {
    let id: UUID
    var mondaySourceID: SourceID?
    var tuesdaySourceID: SourceID?
    var wednesdaySourceID: SourceID?
    var thursdaySourceID: SourceID?
    var fridaySourceID: SourceID?
    var saturdaySourceID: SourceID?
    var sundaySourceID: SourceID?
    var defaultSourceID: SourceID?
    var updatedAt: Date

    func sourceID(for weekday: Weekday) -> SourceID? {
        switch weekday {
        case .monday:
            mondaySourceID
        case .tuesday:
            tuesdaySourceID
        case .wednesday:
            wednesdaySourceID
        case .thursday:
            thursdaySourceID
        case .friday:
            fridaySourceID
        case .saturday:
            saturdaySourceID
        case .sunday:
            sundaySourceID
        }
    }

    mutating func setSourceID(
        _ sourceID: SourceID?,
        for weekday: Weekday,
        updatedAt: Date
    ) {
        switch weekday {
        case .monday:
            mondaySourceID = sourceID
        case .tuesday:
            tuesdaySourceID = sourceID
        case .wednesday:
            wednesdaySourceID = sourceID
        case .thursday:
            thursdaySourceID = sourceID
        case .friday:
            fridaySourceID = sourceID
        case .saturday:
            saturdaySourceID = sourceID
        case .sunday:
            sundaySourceID = sourceID
        }
        self.updatedAt = updatedAt
    }

    mutating func assignAllDays(to sourceID: SourceID?, updatedAt: Date) {
        for weekday in Weekday.allCases {
            setSourceID(sourceID, for: weekday, updatedAt: updatedAt)
        }
    }

    mutating func clearReferences(to sourceID: SourceID, updatedAt: Date) {
        if mondaySourceID == sourceID { mondaySourceID = nil }
        if tuesdaySourceID == sourceID { tuesdaySourceID = nil }
        if wednesdaySourceID == sourceID { wednesdaySourceID = nil }
        if thursdaySourceID == sourceID { thursdaySourceID = nil }
        if fridaySourceID == sourceID { fridaySourceID = nil }
        if saturdaySourceID == sourceID { saturdaySourceID = nil }
        if sundaySourceID == sourceID { sundaySourceID = nil }
        if defaultSourceID == sourceID { defaultSourceID = nil }
        self.updatedAt = updatedAt
    }
}
