import Foundation

nonisolated enum PersistenceModelMapper {
    static func source(_ value: PersistedWallpaperSource) throws -> WallpaperSource {
        guard let url = URL(string: value.urlString) else {
            throw RepositoryError.invalidPersistedValue(entity: .source, field: "url")
        }
        guard let fetchStatus = SourceFetchStatus(rawValue: value.lastFetchStatusRaw) else {
            throw RepositoryError.invalidPersistedValue(
                entity: .source,
                field: "lastFetchStatus"
            )
        }
        let errorCode = try optionalRawValue(
            value.lastErrorCodeRaw,
            entity: .source,
            field: "lastErrorCode",
            transform: AppErrorCode.init(rawValue:)
        )

        return WallpaperSource(
            id: SourceID(rawValue: value.id),
            name: value.name,
            url: url,
            isEnabled: value.isEnabled,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt,
            lastFetchAt: value.lastFetchAt,
            lastFetchStatus: fetchStatus,
            lastErrorCode: errorCode,
            lastErrorMessage: value.lastErrorMessage,
            consecutiveFailureDays: value.consecutiveFailureDays
        )
    }

    static func wallpaper(_ value: PersistedWallpaper) throws -> Wallpaper {
        guard let path = ManagedRelativePath(rawValue: value.relativePath) else {
            throw RepositoryError.invalidPersistedValue(entity: .wallpaper, field: "relativePath")
        }
        guard let day = LocalDay(rawValue: value.downloadDayRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .wallpaper, field: "downloadDay")
        }
        guard let format = WallpaperFormat(rawValue: value.formatRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .wallpaper, field: "format")
        }
        guard let fileState = WallpaperFileState(rawValue: value.fileStateRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .wallpaper, field: "fileState")
        }

        return Wallpaper(
            id: WallpaperID(rawValue: value.id),
            contentHash: value.contentHash,
            sourceID: value.sourceID.map(SourceID.init(rawValue:)),
            sourceNameSnapshot: value.sourceNameSnapshot,
            relativePath: path,
            downloadDay: day,
            createdAt: value.createdAt,
            pixelWidth: value.pixelWidth,
            pixelHeight: value.pixelHeight,
            fileSize: value.fileSize,
            format: format,
            fileState: fileState,
            isCurrent: value.isCurrent
        )
    }

    static func schedule(_ value: PersistedWeeklySchedule) -> WeeklySchedule {
        WeeklySchedule(
            id: value.id,
            mondaySourceID: value.mondaySourceID.map(SourceID.init(rawValue:)),
            tuesdaySourceID: value.tuesdaySourceID.map(SourceID.init(rawValue:)),
            wednesdaySourceID: value.wednesdaySourceID.map(SourceID.init(rawValue:)),
            thursdaySourceID: value.thursdaySourceID.map(SourceID.init(rawValue:)),
            fridaySourceID: value.fridaySourceID.map(SourceID.init(rawValue:)),
            saturdaySourceID: value.saturdaySourceID.map(SourceID.init(rawValue:)),
            sundaySourceID: value.sundaySourceID.map(SourceID.init(rawValue:)),
            defaultSourceID: value.defaultSourceID.map(SourceID.init(rawValue:)),
            updatedAt: value.updatedAt
        )
    }

    static func settings(_ value: PersistedUserSettings) throws -> UserSettings {
        guard let wallpaperMode = WallpaperMode(rawValue: value.wallpaperModeRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .settings, field: "wallpaperMode")
        }
        guard let retentionPolicy = RetentionPolicy(rawValue: value.retentionPolicyRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .settings, field: "retentionPolicy")
        }
        guard let slideshowOrder = SlideshowOrder(rawValue: value.slideshowOrderRaw) else {
            throw RepositoryError.invalidPersistedValue(entity: .settings, field: "slideshowOrder")
        }
        guard let slideshowInterval = SlideshowInterval(rawValue: value.slideshowIntervalRaw) else {
            throw RepositoryError.invalidPersistedValue(
                entity: .settings,
                field: "slideshowInterval"
            )
        }
        guard let navigation = NavigationDestination(
            rawValue: value.lastSelectedNavigationRaw
        ) else {
            throw RepositoryError.invalidPersistedValue(entity: .settings, field: "navigation")
        }

        return UserSettings(
            id: value.id,
            launchAtLogin: value.launchAtLogin,
            wallpaperMode: wallpaperMode,
            retentionPolicy: retentionPolicy,
            slideshowOrder: slideshowOrder,
            slideshowInterval: slideshowInterval,
            onboardingCompleted: value.onboardingCompleted,
            lastSelectedNavigation: navigation,
            updatedAt: value.updatedAt
        )
    }

    static func record(_ value: PersistedDailyFetchRecord) throws -> DailyFetchRecord {
        guard let day = LocalDay(rawValue: value.localDayRaw) else {
            throw RepositoryError.invalidPersistedValue(
                entity: .dailyFetchRecord,
                field: "localDay"
            )
        }
        guard let taskKind = FetchTaskKind(rawValue: value.taskKindRaw) else {
            throw RepositoryError.invalidPersistedValue(
                entity: .dailyFetchRecord,
                field: "taskKind"
            )
        }
        guard let status = DailyFetchStatus(rawValue: value.statusRaw) else {
            throw RepositoryError.invalidPersistedValue(
                entity: .dailyFetchRecord,
                field: "status"
            )
        }
        let errorCode = try optionalRawValue(
            value.lastErrorCodeRaw,
            entity: .dailyFetchRecord,
            field: "lastErrorCode",
            transform: AppErrorCode.init(rawValue:)
        )

        return DailyFetchRecord(
            id: DailyFetchRecordID(rawValue: value.id),
            taskKey: value.taskKey,
            localDay: day,
            taskKind: taskKind,
            plannedSourceID: value.plannedSourceID.map(SourceID.init(rawValue:)),
            actualSourceID: value.actualSourceID.map(SourceID.init(rawValue:)),
            status: status,
            automaticAttemptCount: value.automaticAttemptCount,
            usedDefaultSource: value.usedDefaultSource,
            wallpaperID: value.wallpaperID.map(WallpaperID.init(rawValue:)),
            lastAttemptAt: value.lastAttemptAt,
            nextRetryAt: value.nextRetryAt,
            lastErrorCode: errorCode
        )
    }

    private static func optionalRawValue<Value>(
        _ rawValue: String?,
        entity: RepositoryEntity,
        field: String,
        transform: (String) -> Value?
    ) throws -> Value? {
        guard let rawValue else {
            return nil
        }
        guard let value = transform(rawValue) else {
            throw RepositoryError.invalidPersistedValue(entity: entity, field: field)
        }
        return value
    }
}
