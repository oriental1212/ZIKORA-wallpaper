import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct DomainValueTests {
    @Test("Strong identifiers preserve UUID identity through Codable")
    func identifiersRoundTrip() throws {
        let uuid = UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
        let sourceID = SourceID(rawValue: uuid)
        let encoded = try JSONEncoder().encode(sourceID)

        #expect(try JSONDecoder().decode(SourceID.self, from: encoded) == sourceID)
        #expect(WallpaperID(rawValue: uuid).rawValue == uuid)
        #expect(DailyFetchRecordID(rawValue: uuid).rawValue == uuid)
    }

    @Test("LocalDay follows the injected time zone at a local midnight boundary")
    func localDayTimeZoneBoundary() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-08-18T16:30:00Z"))
        let shanghai = calendar(timeZoneIdentifier: "Asia/Shanghai")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")

        #expect(LocalDay(containing: instant, calendar: shanghai).rawValue == "2026-08-19")
        #expect(LocalDay(containing: instant, calendar: losAngeles).rawValue == "2026-08-18")
    }

    @Test("Weekday calculation remains correct across a DST transition")
    func weekdayAndDST() throws {
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let beforeDST = try #require(ISO8601DateFormatter().date(from: "2026-03-08T09:30:00Z"))
        let afterDST = try #require(ISO8601DateFormatter().date(from: "2026-03-08T10:30:00Z"))
        let firstDay = LocalDay(containing: beforeDST, calendar: losAngeles)
        let secondDay = LocalDay(containing: afterDST, calendar: losAngeles)

        #expect(firstDay == secondDay)
        #expect(firstDay.weekday(calendar: losAngeles) == .sunday)
        #expect(LocalDay(rawValue: "2026-08-17")?.weekday(calendar: losAngeles) == .monday)
    }

    @Test("LocalDay rejects non-ISO and impossible dates")
    func localDayValidation() {
        #expect(LocalDay(rawValue: "2026-8-19") == nil)
        #expect(LocalDay(rawValue: "2026-02-29") == nil)
        #expect(LocalDay(rawValue: "2024-02-29") != nil)
        #expect(LocalDay(rawValue: "2026-02-30") == nil)
    }

    @Test("LocalDay uses validated single-value persistence")
    func localDayCodable() throws {
        let day = try #require(LocalDay(rawValue: "2026-08-19"))
        let encoded = try JSONEncoder().encode(day)

        #expect(String(data: encoded, encoding: .utf8) == "\"2026-08-19\"")
        #expect(try JSONDecoder().decode(LocalDay.self, from: encoded) == day)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalDay.self, from: Data("\"2026-02-30\"".utf8))
        }
    }

    @Test("Persistent enum values are stable and language independent")
    func persistentRawValues() {
        #expect(WallpaperMode.daily.rawValue == "daily")
        #expect(WallpaperMode.slideshow.rawValue == "slideshow")
        #expect(SlideshowOrder.chronological.rawValue == "chronological")
        #expect(RetentionPolicy.thirtyDays.rawValue == "days_30")
        #expect(SlideshowInterval.thirtyMinutes.rawValue == "30m")
        #expect(DailyFetchStatus.retryScheduled.rawValue == "retry_scheduled")
        #expect(FetchTaskKind.automaticDaily.rawValue == "automatic_daily")
        #expect(WallpaperFormat.webP.rawValue == "webp")
        #expect(AppErrorCode.invalidURL.rawValue == "invalidURL")
    }

    @Test("Settings defaults match the accepted product baseline")
    func settingsDefaults() {
        #expect(AppDefaults.launchAtLogin)
        #expect(AppDefaults.wallpaperMode == .daily)
        #expect(AppDefaults.retentionPolicy == .thirtyDays)
        #expect(AppDefaults.retentionPolicy.dayCount == 30)
        #expect(AppDefaults.slideshowOrder == .random)
        #expect(AppDefaults.slideshowInterval == .thirtyMinutes)
        #expect(AppDefaults.slideshowInterval.duration == .seconds(30 * 60))
        #expect(!AppDefaults.onboardingCompleted)
        #expect(AppDefaults.lastSelectedNavigation == .dashboard)
    }

    @Test("Source health is derived from persisted result data")
    func sourceHealth() {
        #expect(SourceHealthStatus.evaluate(
            isEnabled: false,
            lastFetchStatus: .success,
            consecutiveFailureDays: 0
        ) == .disabled)
        #expect(SourceHealthStatus.evaluate(
            isEnabled: true,
            lastFetchStatus: .never,
            consecutiveFailureDays: 0
        ) == .unknown)
        #expect(SourceHealthStatus.evaluate(
            isEnabled: true,
            lastFetchStatus: .success,
            consecutiveFailureDays: 0
        ) == .healthy)
        #expect(SourceHealthStatus.evaluate(
            isEnabled: true,
            lastFetchStatus: .failed,
            consecutiveFailureDays: 2
        ) == .failing)
        #expect(SourceHealthStatus.evaluate(
            isEnabled: true,
            lastFetchStatus: .offline,
            consecutiveFailureDays: 3
        ) == .warning)
    }

    @Test("Supported wallpaper formats provide canonical file extensions")
    func wallpaperFormats() {
        #expect(WallpaperFormat.allCases.map(\.rawValue) == ["jpeg", "png", "heic", "webp"])
        #expect(WallpaperFormat.jpeg.preferredFileExtension == "jpg")
        #expect(WallpaperFormat.webP.preferredFileExtension == "webp")
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            preconditionFailure("Test time zone must be available: \(timeZoneIdentifier)")
        }
        calendar.timeZone = timeZone
        return calendar
    }
}
