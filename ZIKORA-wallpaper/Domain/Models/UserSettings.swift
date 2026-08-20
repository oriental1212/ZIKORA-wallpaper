import Foundation

nonisolated struct UserSettings: Codable, Equatable, Sendable {
    let id: UUID
    var launchAtLogin: Bool
    var wallpaperMode: WallpaperMode
    var retentionPolicy: RetentionPolicy
    var slideshowOrder: SlideshowOrder
    var slideshowInterval: SlideshowInterval
    var onboardingCompleted: Bool
    var lastSelectedNavigation: NavigationDestination
    var updatedAt: Date

    static func defaults(id: UUID, updatedAt: Date) -> UserSettings {
        UserSettings(
            id: id,
            launchAtLogin: AppDefaults.launchAtLogin,
            wallpaperMode: AppDefaults.wallpaperMode,
            retentionPolicy: AppDefaults.retentionPolicy,
            slideshowOrder: AppDefaults.slideshowOrder,
            slideshowInterval: AppDefaults.slideshowInterval,
            onboardingCompleted: AppDefaults.onboardingCompleted,
            lastSelectedNavigation: AppDefaults.lastSelectedNavigation,
            updatedAt: updatedAt
        )
    }
}
