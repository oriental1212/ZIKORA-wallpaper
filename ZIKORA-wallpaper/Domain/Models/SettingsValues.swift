import Foundation

nonisolated enum WallpaperMode: String, CaseIterable, Codable, Sendable {
    case daily
    case slideshow
}

nonisolated enum SlideshowOrder: String, CaseIterable, Codable, Sendable {
    case random
    case chronological
}

nonisolated enum SlideshowInterval: String, CaseIterable, Codable, Sendable {
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case threeHours = "3h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"

    var duration: Duration {
        switch self {
        case .fiveMinutes:
            .seconds(5 * 60)
        case .fifteenMinutes:
            .seconds(15 * 60)
        case .thirtyMinutes:
            .seconds(30 * 60)
        case .oneHour:
            .seconds(60 * 60)
        case .threeHours:
            .seconds(3 * 60 * 60)
        case .sixHours:
            .seconds(6 * 60 * 60)
        case .twelveHours:
            .seconds(12 * 60 * 60)
        case .oneDay:
            .seconds(24 * 60 * 60)
        }
    }
}

nonisolated enum RetentionPolicy: String, CaseIterable, Codable, Sendable {
    case sevenDays = "days_7"
    case fourteenDays = "days_14"
    case thirtyDays = "days_30"
    case sixtyDays = "days_60"
    case ninetyDays = "days_90"
    case forever

    var dayCount: Int? {
        switch self {
        case .sevenDays:
            7
        case .fourteenDays:
            14
        case .thirtyDays:
            30
        case .sixtyDays:
            60
        case .ninetyDays:
            90
        case .forever:
            nil
        }
    }
}

nonisolated enum NavigationDestination: String, CaseIterable, Codable, Sendable {
    case dashboard
    case sources
    case library
    case settings
}

nonisolated enum AppDefaults {
    static let launchAtLogin = true
    static let wallpaperMode = WallpaperMode.daily
    static let retentionPolicy = RetentionPolicy.thirtyDays
    static let slideshowOrder = SlideshowOrder.random
    static let slideshowInterval = SlideshowInterval.thirtyMinutes
    static let onboardingCompleted = false
    static let lastSelectedNavigation = NavigationDestination.dashboard
}
