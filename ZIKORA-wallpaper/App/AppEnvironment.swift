import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let clock: any Clock
    let calendar: any CalendarProviding
    let uuidGenerator: any UUIDGenerating
    let randomSelector: any RandomSelecting
    let logger: any AppLogging
    private(set) var repository: (any RepositoryStore)?
    private(set) var services: AppServices?

    init(
        clock: any Clock,
        calendar: any CalendarProviding,
        uuidGenerator: any UUIDGenerating,
        randomSelector: any RandomSelecting,
        logger: any AppLogging,
        repository: (any RepositoryStore)? = nil
    ) {
        self.clock = clock
        self.calendar = calendar
        self.uuidGenerator = uuidGenerator
        self.randomSelector = randomSelector
        self.logger = logger
        self.repository = repository
    }

    static func live() -> AppEnvironment {
        AppEnvironment(
            clock: SystemClock(),
            calendar: SystemCalendarProvider(),
            uuidGenerator: SystemUUIDGenerator(),
            randomSelector: SystemRandomSelector(),
            logger: UnifiedAppLogger(),
            repository: try? InMemoryRepositoryStore()
        )
    }

    func configurePersistentStore(container: ModelContainer, managedRootURL: URL) {
        guard services == nil else { return }
        let repository = SwiftDataRepositoryStore(modelContainer: container)
        self.repository = repository
        services = try? AppServices(
            repository: repository,
            managedRootURL: managedRootURL,
            clock: clock,
            calendar: calendar,
            uuidGenerator: uuidGenerator,
            randomSelector: randomSelector,
            logger: logger
        )
    }

    func startServices() async {
        await services?.start()
    }

    func shutdownServices() async {
        await services?.shutdown()
    }

    static func preview(
        date: Date = Date(timeIntervalSince1970: 0),
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current,
        uuid: UUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        randomIndex: Int = 0
    ) -> AppEnvironment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return AppEnvironment(
            clock: FixedClock(date: date),
            calendar: FixedCalendarProvider(value: calendar),
            uuidGenerator: FixedUUIDGenerator(value: uuid),
            randomSelector: FixedRandomSelector(value: randomIndex),
            logger: NoOpAppLogger(),
            repository: try? InMemoryRepositoryStore()
        )
    }
}
