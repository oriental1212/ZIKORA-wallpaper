import Foundation

nonisolated struct PrepareWeeklyPlanUseCase: Sendable {
    private let sources: any SourceRepository
    private let schedules: any ScheduleRepository
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating

    init(
        sources: any SourceRepository,
        schedules: any ScheduleRepository,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.sources = sources
        self.schedules = schedules
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.uuidGenerator = uuidGenerator
    }

    func execute() async throws -> WeeklyPlanSnapshot {
        let allSources = try await sources.allSources()
        let schedule: WeeklySchedule
        if let existing = try await schedules.loadSchedule() {
            schedule = existing
        } else {
            let now = await clock.now()
            let enabledSources = allSources.filter(\.isEnabled)
            var initial = WeeklySchedule(
                id: await uuidGenerator.makeUUID(),
                mondaySourceID: nil,
                tuesdaySourceID: nil,
                wednesdaySourceID: nil,
                thursdaySourceID: nil,
                fridaySourceID: nil,
                saturdaySourceID: nil,
                sundaySourceID: nil,
                defaultSourceID: nil,
                updatedAt: now
            )
            if enabledSources.count == 1 {
                initial.assignAllDays(to: enabledSources[0].id, updatedAt: now)
            }
            do {
                try await schedules.save(initial)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw WeeklyPlanError.scheduleSaveFailed(previousSchedule: nil)
            }
            schedule = initial
        }

        let snapshotDate = await clock.now()
        let calendar = await calendarProvider.calendar()
        return Self.snapshot(
            schedule: schedule,
            sources: allSources,
            now: snapshotDate,
            calendar: calendar
        )
    }

    static func snapshot(
        schedule: WeeklySchedule,
        sources: [WallpaperSource],
        now: Date,
        calendar: Calendar
    ) -> WeeklyPlanSnapshot {
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let today = LocalDay(containing: now, calendar: calendar).weekday(calendar: calendar)
        let rows = Weekday.allCases.map { weekday in
            WeeklyPlanRow(
                weekday: weekday,
                referenceState: referenceState(
                    sourceID: schedule.sourceID(for: weekday),
                    sourcesByID: sourcesByID
                ),
                isToday: weekday == today
            )
        }
        let selectableSources = sources.compactMap { source in
            source.isEnabled ? WeeklyPlanSourceOption(id: source.id, name: source.name) : nil
        }
        return WeeklyPlanSnapshot(
            schedule: schedule,
            rows: rows,
            selectableSources: selectableSources
        )
    }

    private static func referenceState(
        sourceID: SourceID?,
        sourcesByID: [SourceID: WallpaperSource]
    ) -> WeeklyPlanReferenceState {
        guard let sourceID else {
            return .unset
        }
        guard let source = sourcesByID[sourceID] else {
            return .missing(sourceID: sourceID)
        }
        return source.isEnabled
            ? .available(sourceID: sourceID, name: source.name)
            : .disabled(sourceID: sourceID, name: source.name)
    }
}

nonisolated struct UpdateWeeklyPlanDayUseCase: Sendable {
    private let sources: any SourceRepository
    private let schedules: any ScheduleRepository
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerating

    init(
        sources: any SourceRepository,
        schedules: any ScheduleRepository,
        clock: any Clock = SystemClock(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.sources = sources
        self.schedules = schedules
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    func execute(weekday: Weekday, sourceID: SourceID?) async throws -> WeeklySchedule {
        if let sourceID {
            guard let source = try await sources.source(id: sourceID), source.isEnabled else {
                throw WeeklyPlanError.sourceUnavailable(sourceID)
            }
        }

        let previous = try await schedules.loadSchedule()
        if let previous, previous.sourceID(for: weekday) == sourceID {
            return previous
        }

        let now = await clock.now()
        var updated: WeeklySchedule
        if let previous {
            updated = previous
        } else {
            updated = WeeklySchedule(
                id: await uuidGenerator.makeUUID(),
                mondaySourceID: nil,
                tuesdaySourceID: nil,
                wednesdaySourceID: nil,
                thursdaySourceID: nil,
                fridaySourceID: nil,
                saturdaySourceID: nil,
                sundaySourceID: nil,
                defaultSourceID: nil,
                updatedAt: now
            )
        }
        updated.setSourceID(sourceID, for: weekday, updatedAt: now)

        do {
            try await schedules.save(updated)
            return updated
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WeeklyPlanError.scheduleSaveFailed(previousSchedule: previous)
        }
    }
}
