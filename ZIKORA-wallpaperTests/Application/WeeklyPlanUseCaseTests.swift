import Foundation
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct WeeklyPlanUseCaseTests {
    enum Backend: String, CaseIterable, Sendable {
        case inMemory
        case swiftData
    }

    @Test("A first schedule assigns the only enabled source to all seven fixed rows", arguments: Backend.allCases)
    func firstScheduleDefault(backend: Backend) async throws {
        let store = try makeStore(backend)
        let enabled = try source(id: 1, name: "Only enabled", isEnabled: true)
        let disabled = try source(id: 2, name: "Disabled", isEnabled: false)
        try await store.save(enabled)
        try await store.save(disabled)
        let now = date(year: 2026, month: 8, day: 19, hour: 8)
        let snapshot = try await PrepareWeeklyPlanUseCase(
            sources: store,
            schedules: store,
            clock: FixedClock(date: now),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai")),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(20))
        ).execute()

        #expect(snapshot.rows.map(\.weekday) == Weekday.allCases)
        #expect(snapshot.rows.allSatisfy {
            $0.referenceState == .available(sourceID: enabled.id, name: enabled.name)
        })
        #expect(snapshot.rows.filter(\.isToday).map(\.weekday) == [.wednesday])
        #expect(snapshot.selectableSources == [WeeklyPlanSourceOption(
            id: enabled.id,
            name: enabled.name
        )])
        #expect(snapshot.schedule.defaultSourceID == nil)
        #expect(try await store.loadSchedule() == snapshot.schedule)
    }

    @Test("Each weekday saves independently and unset remains a valid selection", arguments: Backend.allCases)
    func independentDayUpdates(backend: Backend) async throws {
        let store = try makeStore(backend)
        let sources = try Weekday.allCases.enumerated().map { index, weekday in
            try source(id: UInt8(index + 1), name: "Source \(weekday.rawValue)", isEnabled: true)
        }
        for source in sources {
            try await store.save(source)
        }
        let useCase = UpdateWeeklyPlanDayUseCase(
            sources: store,
            schedules: store,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_787_100_000)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(30))
        )

        for (weekday, source) in zip(Weekday.allCases, sources) {
            _ = try await useCase.execute(weekday: weekday, sourceID: source.id)
        }
        var schedule = try #require(try await store.loadSchedule())
        for (weekday, source) in zip(Weekday.allCases, sources) {
            #expect(schedule.sourceID(for: weekday) == source.id)
        }

        schedule = try await useCase.execute(weekday: .saturday, sourceID: nil)
        #expect(schedule.saturdaySourceID == nil)
        #expect(schedule.fridaySourceID == sources[4].id)
        #expect(schedule.sundaySourceID == sources[6].id)
    }

    @Test("Disabled and missing references stay visible but cannot be newly selected", arguments: Backend.allCases)
    func unavailableReferences(backend: Backend) async throws {
        let store = try makeStore(backend)
        let enabled = try source(id: 1, name: "Enabled", isEnabled: true)
        let disabled = try source(id: 2, name: "Disabled", isEnabled: false)
        let missingID = SourceID(rawValue: fixedUUID(3))
        try await store.save(enabled)
        try await store.save(disabled)
        let existing = schedule(
            monday: disabled.id,
            tuesday: missingID,
            updatedAt: Date(timeIntervalSince1970: 1_787_000_000)
        )
        try await store.save(existing)
        let now = date(year: 2026, month: 8, day: 19, hour: 8)
        let snapshot = try await PrepareWeeklyPlanUseCase(
            sources: store,
            schedules: store,
            clock: FixedClock(date: now),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "UTC"))
        ).execute()

        #expect(snapshot.rows[0].referenceState == .disabled(
            sourceID: disabled.id,
            name: disabled.name
        ))
        #expect(snapshot.rows[1].referenceState == .missing(sourceID: missingID))
        #expect(snapshot.selectableSources.map(\.id) == [enabled.id])
        #expect(snapshot.schedule == existing)

        let update = UpdateWeeklyPlanDayUseCase(sources: store, schedules: store)
        await #expect(throws: WeeklyPlanError.sourceUnavailable(disabled.id)) {
            try await update.execute(weekday: .wednesday, sourceID: disabled.id)
        }
        await #expect(throws: WeeklyPlanError.sourceUnavailable(missingID)) {
            try await update.execute(weekday: .wednesday, sourceID: missingID)
        }
        #expect(try await store.loadSchedule() == existing)
    }

    @Test("A save failure exposes the previous schedule for exact UI rollback")
    func saveFailureRollback() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try source(id: 1, name: "Keep", isEnabled: true)
        let existing = schedule(
            monday: source.id,
            tuesday: nil,
            updatedAt: Date(timeIntervalSince1970: 1_787_000_000)
        )
        try await store.save(source)
        let failingSchedules = FailingScheduleRepository(existing: existing)
        let useCase = UpdateWeeklyPlanDayUseCase(
            sources: store,
            schedules: failingSchedules,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_787_100_000))
        )

        await #expect(throws: WeeklyPlanError.scheduleSaveFailed(previousSchedule: existing)) {
            try await useCase.execute(weekday: .tuesday, sourceID: source.id)
        }
        #expect(try await failingSchedules.loadSchedule() == existing)
    }

    @Test("An existing empty plan is not silently replaced when sources later change")
    func existingPlanIsNotReinitialized() async throws {
        let store = try InMemoryRepositoryStore()
        let existing = schedule(
            monday: nil,
            tuesday: nil,
            updatedAt: Date(timeIntervalSince1970: 1_787_000_000)
        )
        try await store.save(existing)
        try await store.save(try source(id: 1, name: "Later", isEnabled: true))

        let snapshot = try await PrepareWeeklyPlanUseCase(
            sources: store,
            schedules: store,
            clock: FixedClock(date: date(year: 2026, month: 8, day: 19, hour: 8)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "UTC"))
        ).execute()

        #expect(snapshot.schedule == existing)
        #expect(snapshot.rows.allSatisfy { $0.referenceState == .unset })
    }

    @Test("Today mapping follows the injected time zone and is independent of locale")
    func todayMapping() {
        let instant = date(year: 2026, month: 8, day: 19, hour: 0)
        let value = schedule(
            monday: nil,
            tuesday: nil,
            updatedAt: instant
        )
        var chineseCalendar = calendar(timeZoneID: "Asia/Shanghai")
        chineseCalendar.locale = Locale(identifier: "zh_CN")
        var frenchCalendar = calendar(timeZoneID: "Asia/Shanghai")
        frenchCalendar.locale = Locale(identifier: "fr_FR")
        let losAngelesCalendar = calendar(timeZoneID: "America/Los_Angeles")

        let chinese = PrepareWeeklyPlanUseCase.snapshot(
            schedule: value,
            sources: [],
            now: instant,
            calendar: chineseCalendar
        )
        let french = PrepareWeeklyPlanUseCase.snapshot(
            schedule: value,
            sources: [],
            now: instant,
            calendar: frenchCalendar
        )
        let losAngeles = PrepareWeeklyPlanUseCase.snapshot(
            schedule: value,
            sources: [],
            now: instant,
            calendar: losAngelesCalendar
        )

        #expect(chinese.rows.filter(\.isToday).map(\.weekday) == [.wednesday])
        #expect(french.rows.filter(\.isToday).map(\.weekday) == [.wednesday])
        #expect(losAngeles.rows.filter(\.isToday).map(\.weekday) == [.tuesday])
    }

    private func makeStore(_ backend: Backend) throws -> any RepositoryStore {
        switch backend {
        case .inMemory:
            try InMemoryRepositoryStore()
        case .swiftData:
            SwiftDataRepositoryStore(
                modelContainer: try PersistenceContainerFactory.makeInMemoryStore()
            )
        }
    }

    private func source(
        id: UInt8,
        name: String,
        isEnabled: Bool
    ) throws -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: fixedUUID(id)),
            name: name,
            url: try #require(URL(string: "https://example.test/\(id).png")),
            isEnabled: isEnabled,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id)),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }

    private func schedule(
        monday: SourceID?,
        tuesday: SourceID?,
        updatedAt: Date
    ) -> WeeklySchedule {
        WeeklySchedule(
            id: fixedUUID(40),
            mondaySourceID: monday,
            tuesdaySourceID: tuesday,
            wednesdaySourceID: nil,
            thursdaySourceID: nil,
            fridaySourceID: nil,
            saturdaySourceID: nil,
            sundaySourceID: nil,
            defaultSourceID: nil,
            updatedAt: updatedAt
        )
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar(timeZoneID: "UTC")
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? .distantPast
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private actor FailingScheduleRepository: ScheduleRepository {
    private let existing: WeeklySchedule?

    init(existing: WeeklySchedule?) {
        self.existing = existing
    }

    func loadSchedule() async throws -> WeeklySchedule? {
        existing
    }

    func save(_ schedule: WeeklySchedule) async throws {
        throw RepositoryError.persistenceFailed(entity: .schedule, operation: .save)
    }
}
