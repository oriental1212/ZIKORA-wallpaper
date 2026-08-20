import Foundation

nonisolated enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    init?(foundationWeekday: Int) {
        guard (1...7).contains(foundationWeekday) else {
            return nil
        }

        self.init(rawValue: ((foundationWeekday + 5) % 7) + 1)
    }
}

nonisolated struct LocalDay: Codable, Hashable, RawRepresentable, Sendable, Comparable {
    let rawValue: String

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              Self.formatted(year: year, month: month, day: day) == rawValue,
              Self.isValid(year: year, month: month, day: day) else {
            return nil
        }

        self.rawValue = rawValue
    }

    init(containing date: Date, calendar: Calendar) {
        let localCalendar = Self.gregorianCalendar(timeZone: calendar.timeZone)
        let components = localCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            preconditionFailure("Gregorian calendar must produce year, month, and day components")
        }

        self.rawValue = Self.formatted(year: year, month: month, day: day)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let persistedValue = try container.decode(String.self)
        guard let day = LocalDay(rawValue: persistedValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "LocalDay must be a valid ISO Gregorian date"
            )
        }

        self = day
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    func weekday(calendar: Calendar) -> Weekday {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            preconditionFailure("A validated LocalDay must contain ISO date components")
        }

        let localCalendar = Self.gregorianCalendar(timeZone: calendar.timeZone)
        var components = DateComponents()
        components.calendar = localCalendar
        components.timeZone = localCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        guard let date = localCalendar.date(from: components),
              let weekday = Weekday(
                foundationWeekday: localCalendar.component(.weekday, from: date)
              ) else {
            preconditionFailure("A validated LocalDay must produce a weekday")
        }

        return weekday
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func formatted(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard let universalTimeZone = TimeZone(secondsFromGMT: 0) else {
            preconditionFailure("Foundation must provide the UTC time zone")
        }
        let calendar = gregorianCalendar(timeZone: universalTimeZone)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        guard let date = calendar.date(from: components) else {
            return false
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year && resolved.month == month && resolved.day == day
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
