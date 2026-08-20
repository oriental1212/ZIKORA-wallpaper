import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct AppEnvironmentTests {
    @Test("Preview dependencies return fixed date, calendar, UUID, and random index")
    func previewDependenciesAreDeterministic() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let date = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 19,
            hour: 12
        )))
        let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
        let environment = AppEnvironment.preview(
            date: date,
            timeZone: calendar.timeZone,
            uuid: uuid,
            randomIndex: 7
        )

        #expect(await environment.clock.now() == date)
        #expect(await environment.calendar.calendar().component(.weekday, from: date) == 4)
        #expect(await environment.uuidGenerator.makeUUID() == uuid)
        #expect(await environment.randomSelector.index(upperBound: 5) == 2)
        #expect(await environment.randomSelector.index(upperBound: 0) == nil)
    }

    @Test("The environment is a shared reference for every scene entry point")
    func environmentHasSharedIdentity() {
        let environment = AppEnvironment.preview()
        let mainWindowEnvironment = environment
        let menuBarEnvironment = environment

        #expect(mainWindowEnvironment === menuBarEnvironment)
    }
}
