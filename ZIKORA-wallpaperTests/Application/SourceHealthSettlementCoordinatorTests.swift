import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct SourceHealthSettlementCoordinatorTests {
    @Test("A source is settled at most once per local day")
    func settlesOncePerDay() async throws {
        let source = makeSource()
        let repository = try InMemoryRepositoryStore(sources: [source])
        let coordinator = SourceHealthSettlementCoordinator(
            health: UpdateSourceHealthUseCase(sources: repository),
            clock: FixedClock(date: date(year: 2026, month: 8, day: 19)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai"))
        )

        _ = try await coordinator.settleFailure(
            sourceID: source.id,
            status: .failed,
            errorCode: .networkUnavailable,
            message: "offline"
        )
        #expect(try await coordinator.settleFailure(
            sourceID: source.id,
            status: .failed,
            errorCode: .networkUnavailable,
            message: "offline"
        ) == nil)
        #expect((try await repository.source(id: source.id))?.consecutiveFailureDays == 1)
    }

    @Test("Success clears the daily warning counter")
    func successClearsCounter() async throws {
        var source = makeSource()
        source.consecutiveFailureDays = 3
        let repository = try InMemoryRepositoryStore(sources: [source])
        let coordinator = SourceHealthSettlementCoordinator(
            health: UpdateSourceHealthUseCase(sources: repository),
            clock: FixedClock(date: date(year: 2026, month: 8, day: 19)),
            calendarProvider: FixedCalendarProvider(value: calendar(timeZoneID: "Asia/Shanghai"))
        )

        let updated = try await coordinator.markSuccess(sourceID: source.id)
        #expect(updated.consecutiveFailureDays == 0)
        #expect(updated.lastFetchStatus == .success)
    }

    private func makeSource() -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: UUID()), name: "Test", url: URL(string: "https://example.test/image")!,
            isEnabled: true, createdAt: Date(), updatedAt: Date(), lastFetchAt: nil,
            lastFetchStatus: .never, lastErrorCode: nil, lastErrorMessage: nil, consecutiveFailureDays: 0
        )
    }

    private func calendar(timeZoneID: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return value
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = 12
        return calendar(timeZoneID: "Asia/Shanghai").date(from: components)!
    }
}
