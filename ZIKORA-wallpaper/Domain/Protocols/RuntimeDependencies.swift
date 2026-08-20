import Foundation

nonisolated protocol Clock: Sendable {
    func now() async -> Date
}

nonisolated protocol CalendarProviding: Sendable {
    func calendar() async -> Calendar
}

nonisolated protocol UUIDGenerating: Sendable {
    func makeUUID() async -> UUID
}

nonisolated protocol RandomSelecting: Sendable {
    func index(upperBound: Int) async -> Int?
}

nonisolated struct SystemClock: Clock {
    func now() async -> Date {
        Date()
    }
}

nonisolated struct SystemCalendarProvider: CalendarProviding {
    func calendar() async -> Calendar {
        .autoupdatingCurrent
    }
}

nonisolated struct SystemUUIDGenerator: UUIDGenerating {
    func makeUUID() async -> UUID {
        UUID()
    }
}

nonisolated struct SystemRandomSelector: RandomSelecting {
    func index(upperBound: Int) async -> Int? {
        guard upperBound > 0 else {
            return nil
        }

        return Int.random(in: 0..<upperBound)
    }
}

nonisolated struct FixedClock: Clock {
    let date: Date

    func now() async -> Date {
        date
    }
}

nonisolated struct FixedCalendarProvider: CalendarProviding {
    let value: Calendar

    func calendar() async -> Calendar {
        value
    }
}

nonisolated struct FixedUUIDGenerator: UUIDGenerating {
    let value: UUID

    func makeUUID() async -> UUID {
        value
    }
}

nonisolated struct FixedRandomSelector: RandomSelecting {
    let value: Int

    func index(upperBound: Int) async -> Int? {
        guard upperBound > 0 else {
            return nil
        }

        let remainder = value % upperBound
        return remainder >= 0 ? remainder : remainder + upperBound
    }
}
