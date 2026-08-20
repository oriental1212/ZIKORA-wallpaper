import Foundation
import SwiftData

@ModelActor
actor SwiftDataRepositoryStore: RepositoryStore {
    func allSources() async throws -> [WallpaperSource] {
        try fetching(entity: .source) {
            let descriptor = FetchDescriptor<PersistedWallpaperSource>(
                sortBy: [
                    SortDescriptor(\PersistedWallpaperSource.createdAt, order: .forward),
                    SortDescriptor(\PersistedWallpaperSource.id, order: .forward),
                ]
            )
            return try modelContext.fetch(descriptor).map(PersistenceModelMapper.source)
        }
    }

    func source(id: SourceID) async throws -> WallpaperSource? {
        try fetching(entity: .source) {
            try persistedSource(id: id).map(PersistenceModelMapper.source)
        }
    }

    func save(_ source: WallpaperSource) async throws {
        try saving(entity: .source) {
            if let value = try persistedSource(id: source.id) {
                update(value, from: source)
            } else {
                modelContext.insert(PersistedWallpaperSource(
                    id: source.id,
                    name: source.name,
                    url: source.url,
                    isEnabled: source.isEnabled,
                    createdAt: source.createdAt,
                    updatedAt: source.updatedAt,
                    lastFetchAt: source.lastFetchAt,
                    lastFetchStatus: source.lastFetchStatus,
                    lastErrorCode: source.lastErrorCode,
                    lastErrorMessage: source.lastErrorMessage,
                    consecutiveFailureDays: source.consecutiveFailureDays
                ))
            }
        }
    }

    func delete(id: SourceID, scheduleUpdatedAt: Date) async throws -> SourceDeletionImpact {
        try saving(entity: .source, operation: .transaction) {
            guard let source = try persistedSource(id: id) else {
                throw RepositoryError.notFound(entity: .source)
            }
            let rawID = id.rawValue

            let wallpapers = try modelContext.fetch(FetchDescriptor<PersistedWallpaper>(
                predicate: #Predicate { $0.sourceID == rawID }
            ))
            wallpapers.forEach { $0.sourceID = nil }

            let records = try modelContext.fetch(FetchDescriptor<PersistedDailyFetchRecord>())
            for record in records {
                if record.plannedSourceID == rawID { record.plannedSourceID = nil }
                if record.actualSourceID == rawID { record.actualSourceID = nil }
            }

            let schedules = try modelContext.fetch(FetchDescriptor<PersistedWeeklySchedule>())
            let impact = SourceDeletionImpact(
                sourceID: id,
                sourceName: source.name,
                affectedWeekdays: Weekday.allCases.filter { weekday in
                    schedules.contains { sourceID(for: weekday, in: $0) == rawID }
                },
                wasDefaultSource: schedules.contains { $0.defaultSourceID == rawID }
            )
            for schedule in schedules {
                if references(sourceID: rawID, in: schedule) {
                    clear(sourceID: rawID, from: schedule, updatedAt: scheduleUpdatedAt)
                }
            }

            modelContext.delete(source)
            return impact
        }
    }

    func loadSchedule() async throws -> WeeklySchedule? {
        try fetching(entity: .schedule) {
            var descriptor = FetchDescriptor<PersistedWeeklySchedule>(
                sortBy: [SortDescriptor(\PersistedWeeklySchedule.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first.map(PersistenceModelMapper.schedule)
        }
    }

    func save(_ schedule: WeeklySchedule) async throws {
        try saving(entity: .schedule) {
            let values = try modelContext.fetch(FetchDescriptor<PersistedWeeklySchedule>())
            if let value = values.first(where: { $0.id == schedule.id }) ?? values.first {
                update(value, from: schedule)
                values.filter { $0 !== value }.forEach(modelContext.delete)
            } else {
                modelContext.insert(makePersistedSchedule(schedule))
            }
        }
    }

    func allWallpapers() async throws -> [Wallpaper] {
        try fetching(entity: .wallpaper) {
            let descriptor = FetchDescriptor<PersistedWallpaper>(
                sortBy: [
                    SortDescriptor(\PersistedWallpaper.createdAt, order: .reverse),
                    SortDescriptor(\PersistedWallpaper.id, order: .forward),
                ]
            )
            return try modelContext.fetch(descriptor).map(PersistenceModelMapper.wallpaper)
        }
    }

    func wallpaper(id: WallpaperID) async throws -> Wallpaper? {
        try fetching(entity: .wallpaper) {
            try persistedWallpaper(id: id).map(PersistenceModelMapper.wallpaper)
        }
    }

    func wallpaper(contentHash: String) async throws -> Wallpaper? {
        try fetching(entity: .wallpaper) {
            try persistedWallpaper(contentHash: contentHash).map(PersistenceModelMapper.wallpaper)
        }
    }

    func save(_ wallpaper: Wallpaper) async throws {
        try saving(entity: .wallpaper) {
            if let duplicate = try persistedWallpaper(contentHash: wallpaper.contentHash),
               duplicate.id != wallpaper.id.rawValue {
                throw RepositoryError.duplicateContentHash
            }

            if let value = try persistedWallpaper(id: wallpaper.id) {
                update(value, from: wallpaper)
            } else {
                modelContext.insert(makePersistedWallpaper(wallpaper))
            }
        }
    }

    func delete(id: WallpaperID) async throws {
        try saving(entity: .wallpaper, operation: .delete) {
            guard let value = try persistedWallpaper(id: id) else {
                throw RepositoryError.notFound(entity: .wallpaper)
            }
            modelContext.delete(value)
        }
    }

    func markFileState(id: WallpaperID, state: WallpaperFileState) async throws {
        try saving(entity: .wallpaper) {
            guard let value = try persistedWallpaper(id: id) else {
                throw RepositoryError.notFound(entity: .wallpaper)
            }
            value.fileStateRaw = state.rawValue
        }
    }

    func markCurrent(id: WallpaperID) async throws {
        try saving(entity: .wallpaper, operation: .transaction) {
            guard try persistedWallpaper(id: id) != nil else {
                throw RepositoryError.notFound(entity: .wallpaper)
            }
            let rawID = id.rawValue
            let values = try modelContext.fetch(FetchDescriptor<PersistedWallpaper>())
            values.forEach { $0.isCurrent = $0.id == rawID }
        }
    }

    func allRecords() async throws -> [DailyFetchRecord] {
        try fetching(entity: .dailyFetchRecord) {
            let descriptor = FetchDescriptor<PersistedDailyFetchRecord>(
                sortBy: [
                    SortDescriptor(\PersistedDailyFetchRecord.localDayRaw, order: .reverse),
                    SortDescriptor(\PersistedDailyFetchRecord.lastAttemptAt, order: .reverse),
                    SortDescriptor(\PersistedDailyFetchRecord.id, order: .forward),
                ]
            )
            return try modelContext.fetch(descriptor).map(PersistenceModelMapper.record)
        }
    }

    func record(for day: LocalDay, taskKind: FetchTaskKind) async throws -> DailyFetchRecord? {
        try fetching(entity: .dailyFetchRecord) {
            let dayRaw = day.rawValue
            let kindRaw = taskKind.rawValue
            var descriptor = FetchDescriptor<PersistedDailyFetchRecord>(
                predicate: #Predicate {
                    $0.localDayRaw == dayRaw && $0.taskKindRaw == kindRaw
                },
                sortBy: [
                    SortDescriptor(\PersistedDailyFetchRecord.lastAttemptAt, order: .reverse),
                ]
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first.map(PersistenceModelMapper.record)
        }
    }

    func prepareRecord(
        for day: LocalDay,
        taskKind: FetchTaskKind,
        id: DailyFetchRecordID,
        plannedSourceID: SourceID?
    ) async throws -> DailyFetchRecord {
        try saving(entity: .dailyFetchRecord, operation: .transaction) {
            let dayRaw = day.rawValue
            let automaticKindRaw = FetchTaskKind.automaticDaily.rawValue
            let retryStatusRaw = DailyFetchStatus.retryScheduled.rawValue
            let staleRetries = try modelContext.fetch(FetchDescriptor<PersistedDailyFetchRecord>(
                predicate: #Predicate {
                    $0.taskKindRaw == automaticKindRaw
                        && $0.localDayRaw != dayRaw
                        && $0.statusRaw == retryStatusRaw
                }
            ))
            for record in staleRetries {
                record.statusRaw = DailyFetchStatus.failed.rawValue
                record.nextRetryAt = nil
            }

            let taskKey = DailyFetchRecord.taskKey(for: day, taskKind: taskKind)
            if let existing = try persistedRecord(taskKey: taskKey) {
                return try PersistenceModelMapper.record(existing)
            }

            let record = DailyFetchRecord.pending(
                id: id,
                day: day,
                taskKind: taskKind,
                plannedSourceID: plannedSourceID
            )
            modelContext.insert(makePersistedRecord(record))
            return record
        }
    }

    func save(_ record: DailyFetchRecord) async throws {
        try saving(entity: .dailyFetchRecord) {
            if let duplicate = try persistedRecord(taskKey: record.taskKey),
               duplicate.id != record.id.rawValue {
                throw RepositoryError.duplicateTaskKey
            }

            if let value = try persistedRecord(id: record.id) {
                update(value, from: record)
            } else {
                modelContext.insert(makePersistedRecord(record))
            }
        }
    }

    func loadSettings() async throws -> UserSettings? {
        try fetching(entity: .settings) {
            var descriptor = FetchDescriptor<PersistedUserSettings>(
                sortBy: [SortDescriptor(\PersistedUserSettings.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first.map(PersistenceModelMapper.settings)
        }
    }

    func save(_ settings: UserSettings) async throws {
        try saving(entity: .settings) {
            let values = try modelContext.fetch(FetchDescriptor<PersistedUserSettings>())
            if let value = values.first(where: { $0.id == settings.id }) ?? values.first {
                update(value, from: settings)
                values.filter { $0 !== value }.forEach(modelContext.delete)
            } else {
                modelContext.insert(makePersistedSettings(settings))
            }
        }
    }

    private func fetching<Value>(
        entity: RepositoryEntity,
        _ operation: () throws -> Value
    ) throws -> Value {
        do {
            return try operation()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.persistenceFailed(entity: entity, operation: .fetch)
        }
    }

    private func saving<Value>(
        entity: RepositoryEntity,
        operation: RepositoryOperation = .save,
        _ changes: () throws -> Value
    ) throws -> Value {
        do {
            let value = try changes()
            try modelContext.save()
            return value
        } catch let error as RepositoryError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw RepositoryError.persistenceFailed(entity: entity, operation: operation)
        }
    }

    private func persistedSource(id: SourceID) throws -> PersistedWallpaperSource? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<PersistedWallpaperSource>(
            predicate: #Predicate { $0.id == rawID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func persistedWallpaper(id: WallpaperID) throws -> PersistedWallpaper? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<PersistedWallpaper>(
            predicate: #Predicate { $0.id == rawID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func persistedWallpaper(contentHash: String) throws -> PersistedWallpaper? {
        var descriptor = FetchDescriptor<PersistedWallpaper>(
            predicate: #Predicate { $0.contentHash == contentHash }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func persistedRecord(id: DailyFetchRecordID) throws -> PersistedDailyFetchRecord? {
        let rawID = id.rawValue
        var descriptor = FetchDescriptor<PersistedDailyFetchRecord>(
            predicate: #Predicate { $0.id == rawID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func persistedRecord(taskKey: String) throws -> PersistedDailyFetchRecord? {
        var descriptor = FetchDescriptor<PersistedDailyFetchRecord>(
            predicate: #Predicate { $0.taskKey == taskKey }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func update(_ value: PersistedWallpaperSource, from source: WallpaperSource) {
        value.name = source.name
        value.urlString = source.url.absoluteString
        value.isEnabled = source.isEnabled
        value.createdAt = source.createdAt
        value.updatedAt = source.updatedAt
        value.lastFetchAt = source.lastFetchAt
        value.lastFetchStatusRaw = source.lastFetchStatus.rawValue
        value.lastErrorCodeRaw = source.lastErrorCode?.rawValue
        value.lastErrorMessage = source.lastErrorMessage
        value.consecutiveFailureDays = source.consecutiveFailureDays
    }

    private func makePersistedWallpaper(_ wallpaper: Wallpaper) -> PersistedWallpaper {
        PersistedWallpaper(
            id: wallpaper.id,
            contentHash: wallpaper.contentHash,
            sourceID: wallpaper.sourceID,
            sourceNameSnapshot: wallpaper.sourceNameSnapshot,
            relativePath: wallpaper.relativePath,
            downloadDay: wallpaper.downloadDay,
            createdAt: wallpaper.createdAt,
            pixelWidth: wallpaper.pixelWidth,
            pixelHeight: wallpaper.pixelHeight,
            fileSize: wallpaper.fileSize,
            format: wallpaper.format,
            fileState: wallpaper.fileState,
            isCurrent: wallpaper.isCurrent
        )
    }

    private func update(_ value: PersistedWallpaper, from wallpaper: Wallpaper) {
        value.contentHash = wallpaper.contentHash
        value.sourceID = wallpaper.sourceID?.rawValue
        value.sourceNameSnapshot = wallpaper.sourceNameSnapshot
        value.relativePath = wallpaper.relativePath.rawValue
        value.downloadDayRaw = wallpaper.downloadDay.rawValue
        value.createdAt = wallpaper.createdAt
        value.pixelWidth = wallpaper.pixelWidth
        value.pixelHeight = wallpaper.pixelHeight
        value.fileSize = wallpaper.fileSize
        value.formatRaw = wallpaper.format.rawValue
        value.fileStateRaw = wallpaper.fileState.rawValue
        value.isCurrent = wallpaper.isCurrent
    }

    private func makePersistedSchedule(_ schedule: WeeklySchedule) -> PersistedWeeklySchedule {
        PersistedWeeklySchedule(
            id: schedule.id,
            mondaySourceID: schedule.mondaySourceID,
            tuesdaySourceID: schedule.tuesdaySourceID,
            wednesdaySourceID: schedule.wednesdaySourceID,
            thursdaySourceID: schedule.thursdaySourceID,
            fridaySourceID: schedule.fridaySourceID,
            saturdaySourceID: schedule.saturdaySourceID,
            sundaySourceID: schedule.sundaySourceID,
            defaultSourceID: schedule.defaultSourceID,
            updatedAt: schedule.updatedAt
        )
    }

    private func update(_ value: PersistedWeeklySchedule, from schedule: WeeklySchedule) {
        value.id = schedule.id
        value.mondaySourceID = schedule.mondaySourceID?.rawValue
        value.tuesdaySourceID = schedule.tuesdaySourceID?.rawValue
        value.wednesdaySourceID = schedule.wednesdaySourceID?.rawValue
        value.thursdaySourceID = schedule.thursdaySourceID?.rawValue
        value.fridaySourceID = schedule.fridaySourceID?.rawValue
        value.saturdaySourceID = schedule.saturdaySourceID?.rawValue
        value.sundaySourceID = schedule.sundaySourceID?.rawValue
        value.defaultSourceID = schedule.defaultSourceID?.rawValue
        value.updatedAt = schedule.updatedAt
    }

    private func clear(
        sourceID: UUID,
        from schedule: PersistedWeeklySchedule,
        updatedAt: Date
    ) {
        if schedule.mondaySourceID == sourceID { schedule.mondaySourceID = nil }
        if schedule.tuesdaySourceID == sourceID { schedule.tuesdaySourceID = nil }
        if schedule.wednesdaySourceID == sourceID { schedule.wednesdaySourceID = nil }
        if schedule.thursdaySourceID == sourceID { schedule.thursdaySourceID = nil }
        if schedule.fridaySourceID == sourceID { schedule.fridaySourceID = nil }
        if schedule.saturdaySourceID == sourceID { schedule.saturdaySourceID = nil }
        if schedule.sundaySourceID == sourceID { schedule.sundaySourceID = nil }
        if schedule.defaultSourceID == sourceID { schedule.defaultSourceID = nil }
        schedule.updatedAt = updatedAt
    }

    private func sourceID(for weekday: Weekday, in schedule: PersistedWeeklySchedule) -> UUID? {
        switch weekday {
        case .monday:
            schedule.mondaySourceID
        case .tuesday:
            schedule.tuesdaySourceID
        case .wednesday:
            schedule.wednesdaySourceID
        case .thursday:
            schedule.thursdaySourceID
        case .friday:
            schedule.fridaySourceID
        case .saturday:
            schedule.saturdaySourceID
        case .sunday:
            schedule.sundaySourceID
        }
    }

    private func references(sourceID: UUID, in schedule: PersistedWeeklySchedule) -> Bool {
        schedule.defaultSourceID == sourceID || Weekday.allCases.contains {
            self.sourceID(for: $0, in: schedule) == sourceID
        }
    }

    private func makePersistedSettings(_ settings: UserSettings) -> PersistedUserSettings {
        PersistedUserSettings(
            id: settings.id,
            launchAtLogin: settings.launchAtLogin,
            wallpaperMode: settings.wallpaperMode,
            retentionPolicy: settings.retentionPolicy,
            slideshowOrder: settings.slideshowOrder,
            slideshowInterval: settings.slideshowInterval,
            onboardingCompleted: settings.onboardingCompleted,
            lastSelectedNavigation: settings.lastSelectedNavigation,
            updatedAt: settings.updatedAt
        )
    }

    private func update(_ value: PersistedUserSettings, from settings: UserSettings) {
        value.id = settings.id
        value.launchAtLogin = settings.launchAtLogin
        value.wallpaperModeRaw = settings.wallpaperMode.rawValue
        value.retentionPolicyRaw = settings.retentionPolicy.rawValue
        value.slideshowOrderRaw = settings.slideshowOrder.rawValue
        value.slideshowIntervalRaw = settings.slideshowInterval.rawValue
        value.onboardingCompleted = settings.onboardingCompleted
        value.lastSelectedNavigationRaw = settings.lastSelectedNavigation.rawValue
        value.updatedAt = settings.updatedAt
    }

    private func makePersistedRecord(_ record: DailyFetchRecord) -> PersistedDailyFetchRecord {
        PersistedDailyFetchRecord(
            id: record.id,
            taskKey: record.taskKey,
            localDay: record.localDay,
            taskKind: record.taskKind,
            plannedSourceID: record.plannedSourceID,
            actualSourceID: record.actualSourceID,
            status: record.status,
            automaticAttemptCount: record.automaticAttemptCount,
            usedDefaultSource: record.usedDefaultSource,
            wallpaperID: record.wallpaperID,
            lastAttemptAt: record.lastAttemptAt,
            nextRetryAt: record.nextRetryAt,
            lastErrorCode: record.lastErrorCode
        )
    }

    private func update(_ value: PersistedDailyFetchRecord, from record: DailyFetchRecord) {
        value.taskKey = record.taskKey
        value.localDayRaw = record.localDay.rawValue
        value.taskKindRaw = record.taskKind.rawValue
        value.plannedSourceID = record.plannedSourceID?.rawValue
        value.actualSourceID = record.actualSourceID?.rawValue
        value.statusRaw = record.status.rawValue
        value.automaticAttemptCount = record.automaticAttemptCount
        value.usedDefaultSource = record.usedDefaultSource
        value.wallpaperID = record.wallpaperID?.rawValue
        value.lastAttemptAt = record.lastAttemptAt
        value.nextRetryAt = record.nextRetryAt
        value.lastErrorCodeRaw = record.lastErrorCode?.rawValue
    }
}
