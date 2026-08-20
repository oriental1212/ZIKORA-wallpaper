import Foundation

nonisolated struct PrepareDailyFetchRecordUseCase: Sendable {
    private let repository: any DailyFetchRepository
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating

    init(
        repository: any DailyFetchRepository,
        clock: any Clock = SystemClock(),
        calendarProvider: any CalendarProviding = SystemCalendarProvider(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.repository = repository
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.uuidGenerator = uuidGenerator
    }

    func execute(
        taskKind: FetchTaskKind,
        plannedSourceID: SourceID?
    ) async throws -> DailyFetchRecord {
        async let now = clock.now()
        async let calendar = calendarProvider.calendar()
        async let uuid = uuidGenerator.makeUUID()

        let day = LocalDay(containing: await now, calendar: await calendar)
        return try await repository.prepareRecord(
            for: day,
            taskKind: taskKind,
            id: DailyFetchRecordID(rawValue: await uuid),
            plannedSourceID: plannedSourceID
        )
    }
}
