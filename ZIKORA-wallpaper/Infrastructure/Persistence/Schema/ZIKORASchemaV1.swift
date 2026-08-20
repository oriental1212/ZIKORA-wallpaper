import Foundation
import SwiftData

enum ZIKORASchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WallpaperSource.self,
            Wallpaper.self,
            WeeklySchedule.self,
            UserSettings.self,
            DailyFetchRecord.self,
        ]
    }

    @Model
    final class WallpaperSource {
        @Attribute(.unique) var id: UUID
        var name: String
        var urlString: String
        var isEnabled: Bool
        var createdAt: Date
        var updatedAt: Date
        var lastFetchAt: Date?
        var lastFetchStatusRaw: String
        var lastErrorCodeRaw: String?
        var lastErrorMessage: String?
        var consecutiveFailureDays: Int

        init(
            id: SourceID,
            name: String,
            url: URL,
            isEnabled: Bool,
            createdAt: Date,
            updatedAt: Date,
            lastFetchAt: Date? = nil,
            lastFetchStatus: SourceFetchStatus = .never,
            lastErrorCode: AppErrorCode? = nil,
            lastErrorMessage: String? = nil,
            consecutiveFailureDays: Int = 0
        ) {
            self.id = id.rawValue
            self.name = name
            self.urlString = url.absoluteString
            self.isEnabled = isEnabled
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastFetchAt = lastFetchAt
            self.lastFetchStatusRaw = lastFetchStatus.rawValue
            self.lastErrorCodeRaw = lastErrorCode?.rawValue
            self.lastErrorMessage = lastErrorMessage
            self.consecutiveFailureDays = consecutiveFailureDays
        }
    }

    @Model
    final class Wallpaper {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var contentHash: String
        var sourceID: UUID?
        var sourceNameSnapshot: String
        var relativePath: String
        var downloadDayRaw: String
        var createdAt: Date
        var pixelWidth: Int
        var pixelHeight: Int
        var fileSize: Int64
        var formatRaw: String
        var fileStateRaw: String
        var isCurrent: Bool

        init(
            id: WallpaperID,
            contentHash: String,
            sourceID: SourceID?,
            sourceNameSnapshot: String,
            relativePath: ManagedRelativePath,
            downloadDay: LocalDay,
            createdAt: Date,
            pixelWidth: Int,
            pixelHeight: Int,
            fileSize: Int64,
            format: WallpaperFormat,
            fileState: WallpaperFileState = .available,
            isCurrent: Bool = false
        ) {
            self.id = id.rawValue
            self.contentHash = contentHash
            self.sourceID = sourceID?.rawValue
            self.sourceNameSnapshot = sourceNameSnapshot
            self.relativePath = relativePath.rawValue
            self.downloadDayRaw = downloadDay.rawValue
            self.createdAt = createdAt
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.fileSize = fileSize
            self.formatRaw = format.rawValue
            self.fileStateRaw = fileState.rawValue
            self.isCurrent = isCurrent
        }
    }

    @Model
    final class WeeklySchedule {
        @Attribute(.unique) var id: UUID
        var mondaySourceID: UUID?
        var tuesdaySourceID: UUID?
        var wednesdaySourceID: UUID?
        var thursdaySourceID: UUID?
        var fridaySourceID: UUID?
        var saturdaySourceID: UUID?
        var sundaySourceID: UUID?
        var defaultSourceID: UUID?
        var updatedAt: Date

        init(
            id: UUID,
            mondaySourceID: SourceID? = nil,
            tuesdaySourceID: SourceID? = nil,
            wednesdaySourceID: SourceID? = nil,
            thursdaySourceID: SourceID? = nil,
            fridaySourceID: SourceID? = nil,
            saturdaySourceID: SourceID? = nil,
            sundaySourceID: SourceID? = nil,
            defaultSourceID: SourceID? = nil,
            updatedAt: Date
        ) {
            self.id = id
            self.mondaySourceID = mondaySourceID?.rawValue
            self.tuesdaySourceID = tuesdaySourceID?.rawValue
            self.wednesdaySourceID = wednesdaySourceID?.rawValue
            self.thursdaySourceID = thursdaySourceID?.rawValue
            self.fridaySourceID = fridaySourceID?.rawValue
            self.saturdaySourceID = saturdaySourceID?.rawValue
            self.sundaySourceID = sundaySourceID?.rawValue
            self.defaultSourceID = defaultSourceID?.rawValue
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class UserSettings {
        @Attribute(.unique) var id: UUID
        var launchAtLogin: Bool
        var wallpaperModeRaw: String
        var retentionPolicyRaw: String
        var slideshowOrderRaw: String
        var slideshowIntervalRaw: String
        var onboardingCompleted: Bool
        var lastSelectedNavigationRaw: String
        var updatedAt: Date

        init(
            id: UUID,
            launchAtLogin: Bool = AppDefaults.launchAtLogin,
            wallpaperMode: WallpaperMode = AppDefaults.wallpaperMode,
            retentionPolicy: RetentionPolicy = AppDefaults.retentionPolicy,
            slideshowOrder: SlideshowOrder = AppDefaults.slideshowOrder,
            slideshowInterval: SlideshowInterval = AppDefaults.slideshowInterval,
            onboardingCompleted: Bool = AppDefaults.onboardingCompleted,
            lastSelectedNavigation: NavigationDestination = AppDefaults.lastSelectedNavigation,
            updatedAt: Date
        ) {
            self.id = id
            self.launchAtLogin = launchAtLogin
            self.wallpaperModeRaw = wallpaperMode.rawValue
            self.retentionPolicyRaw = retentionPolicy.rawValue
            self.slideshowOrderRaw = slideshowOrder.rawValue
            self.slideshowIntervalRaw = slideshowInterval.rawValue
            self.onboardingCompleted = onboardingCompleted
            self.lastSelectedNavigationRaw = lastSelectedNavigation.rawValue
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class DailyFetchRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var taskKey: String
        var localDayRaw: String
        var taskKindRaw: String
        var plannedSourceID: UUID?
        var actualSourceID: UUID?
        var statusRaw: String
        var automaticAttemptCount: Int
        var usedDefaultSource: Bool
        var wallpaperID: UUID?
        var lastAttemptAt: Date?
        var nextRetryAt: Date?
        var lastErrorCodeRaw: String?

        init(
            id: DailyFetchRecordID,
            taskKey: String,
            localDay: LocalDay,
            taskKind: FetchTaskKind,
            plannedSourceID: SourceID? = nil,
            actualSourceID: SourceID? = nil,
            status: DailyFetchStatus = .pending,
            automaticAttemptCount: Int = 0,
            usedDefaultSource: Bool = false,
            wallpaperID: WallpaperID? = nil,
            lastAttemptAt: Date? = nil,
            nextRetryAt: Date? = nil,
            lastErrorCode: AppErrorCode? = nil
        ) {
            self.id = id.rawValue
            self.taskKey = taskKey
            self.localDayRaw = localDay.rawValue
            self.taskKindRaw = taskKind.rawValue
            self.plannedSourceID = plannedSourceID?.rawValue
            self.actualSourceID = actualSourceID?.rawValue
            self.statusRaw = status.rawValue
            self.automaticAttemptCount = automaticAttemptCount
            self.usedDefaultSource = usedDefaultSource
            self.wallpaperID = wallpaperID?.rawValue
            self.lastAttemptAt = lastAttemptAt
            self.nextRetryAt = nextRetryAt
            self.lastErrorCodeRaw = lastErrorCode?.rawValue
        }
    }
}

typealias PersistedWallpaperSource = ZIKORASchemaV1.WallpaperSource
typealias PersistedWallpaper = ZIKORASchemaV1.Wallpaper
typealias PersistedWeeklySchedule = ZIKORASchemaV1.WeeklySchedule
typealias PersistedUserSettings = ZIKORASchemaV1.UserSettings
typealias PersistedDailyFetchRecord = ZIKORASchemaV1.DailyFetchRecord
