import Foundation

actor InMemoryRepositoryStore: RepositoryStore {
    private var sources: [SourceID: WallpaperSource]
    private var wallpapers: [WallpaperID: Wallpaper]
    private var wallpaperIDsByHash: [String: WallpaperID]
    private var records: [DailyFetchRecordID: DailyFetchRecord]
    private var recordIDsByTaskKey: [String: DailyFetchRecordID]
    private var schedule: WeeklySchedule?
    private var settings: UserSettings?

    init(
        sources: [WallpaperSource] = [],
        wallpapers: [Wallpaper] = [],
        records: [DailyFetchRecord] = [],
        schedule: WeeklySchedule? = nil,
        settings: UserSettings? = nil
    ) throws {
        self.sources = [:]
        for source in sources {
            self.sources[source.id] = source
        }
        self.wallpapers = [:]
        self.wallpaperIDsByHash = [:]
        for wallpaper in wallpapers {
            if let existingID = wallpaperIDsByHash[wallpaper.contentHash],
               existingID != wallpaper.id {
                throw RepositoryError.duplicateContentHash
            }
            self.wallpapers[wallpaper.id] = wallpaper
            self.wallpaperIDsByHash[wallpaper.contentHash] = wallpaper.id
        }

        self.records = [:]
        self.recordIDsByTaskKey = [:]
        for record in records {
            if let existingID = recordIDsByTaskKey[record.taskKey], existingID != record.id {
                throw RepositoryError.duplicateTaskKey
            }
            self.records[record.id] = record
            self.recordIDsByTaskKey[record.taskKey] = record.id
        }
        self.schedule = schedule
        self.settings = settings
    }

    func allSources() async throws -> [WallpaperSource] {
        sources.values.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
        }
    }

    func source(id: SourceID) async throws -> WallpaperSource? {
        sources[id]
    }

    func save(_ source: WallpaperSource) async throws {
        sources[source.id] = source
    }

    func delete(id: SourceID, scheduleUpdatedAt: Date) async throws -> SourceDeletionImpact {
        guard let source = sources[id] else {
            throw RepositoryError.notFound(entity: .source)
        }

        let impact = SourceDeletionImpact(
            sourceID: id,
            sourceName: source.name,
            affectedWeekdays: Weekday.allCases.filter {
                schedule?.sourceID(for: $0) == id
            },
            wasDefaultSource: schedule?.defaultSourceID == id
        )

        var nextWallpapers = wallpapers
        for (wallpaperID, var wallpaper) in nextWallpapers where wallpaper.sourceID == id {
            wallpaper.sourceID = nil
            nextWallpapers[wallpaperID] = wallpaper
        }

        var nextRecords = records
        for (recordID, var record) in nextRecords {
            if record.plannedSourceID == id { record.plannedSourceID = nil }
            if record.actualSourceID == id { record.actualSourceID = nil }
            nextRecords[recordID] = record
        }

        var nextSchedule = schedule
        if var value = nextSchedule,
           !impact.affectedWeekdays.isEmpty || impact.wasDefaultSource {
            value.clearReferences(to: id, updatedAt: scheduleUpdatedAt)
            nextSchedule = value
        }

        sources[id] = nil
        wallpapers = nextWallpapers
        records = nextRecords
        schedule = nextSchedule
        return impact
    }

    func loadSchedule() async throws -> WeeklySchedule? {
        schedule
    }

    func save(_ schedule: WeeklySchedule) async throws {
        self.schedule = schedule
    }

    func allWallpapers() async throws -> [Wallpaper] {
        wallpapers.values.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
        }
    }

    func wallpaper(id: WallpaperID) async throws -> Wallpaper? {
        wallpapers[id]
    }

    func wallpaper(contentHash: String) async throws -> Wallpaper? {
        guard let id = wallpaperIDsByHash[contentHash] else {
            return nil
        }
        return wallpapers[id]
    }

    func save(_ wallpaper: Wallpaper) async throws {
        if let existingID = wallpaperIDsByHash[wallpaper.contentHash], existingID != wallpaper.id {
            throw RepositoryError.duplicateContentHash
        }

        if let oldValue = wallpapers[wallpaper.id], oldValue.contentHash != wallpaper.contentHash {
            wallpaperIDsByHash[oldValue.contentHash] = nil
        }
        wallpapers[wallpaper.id] = wallpaper
        wallpaperIDsByHash[wallpaper.contentHash] = wallpaper.id
    }

    func delete(id: WallpaperID) async throws {
        guard let wallpaper = wallpapers.removeValue(forKey: id) else {
            throw RepositoryError.notFound(entity: .wallpaper)
        }
        wallpaperIDsByHash[wallpaper.contentHash] = nil
    }

    func markFileState(id: WallpaperID, state: WallpaperFileState) async throws {
        guard var wallpaper = wallpapers[id] else {
            throw RepositoryError.notFound(entity: .wallpaper)
        }
        wallpaper.fileState = state
        wallpapers[id] = wallpaper
    }

    func markCurrent(id: WallpaperID) async throws {
        guard wallpapers[id] != nil else {
            throw RepositoryError.notFound(entity: .wallpaper)
        }

        for (wallpaperID, var wallpaper) in wallpapers {
            wallpaper.isCurrent = wallpaperID == id
            wallpapers[wallpaperID] = wallpaper
        }
    }

    func allRecords() async throws -> [DailyFetchRecord] {
        sortedRecords()
    }

    func record(for day: LocalDay, taskKind: FetchTaskKind) async throws -> DailyFetchRecord? {
        sortedRecords().first {
            $0.localDay == day && $0.taskKind == taskKind
        }
    }

    func prepareRecord(
        for day: LocalDay,
        taskKind: FetchTaskKind,
        id: DailyFetchRecordID,
        plannedSourceID: SourceID?
    ) async throws -> DailyFetchRecord {
        for (recordID, var record) in records
        where record.taskKind == .automaticDaily
            && record.localDay != day
            && record.status == .retryScheduled {
            record.status = .failed
            record.nextRetryAt = nil
            records[recordID] = record
        }

        let taskKey = DailyFetchRecord.taskKey(for: day, taskKind: taskKind)
        if let existingID = recordIDsByTaskKey[taskKey],
           let existing = records[existingID] {
            return existing
        }

        let record = DailyFetchRecord.pending(
            id: id,
            day: day,
            taskKind: taskKind,
            plannedSourceID: plannedSourceID
        )
        records[id] = record
        recordIDsByTaskKey[taskKey] = id
        return record
    }

    private func sortedRecords() -> [DailyFetchRecord] {
        records.values.sorted {
            if $0.localDay != $1.localDay {
                return $0.localDay > $1.localDay
            }
            let firstAttempt = $0.lastAttemptAt ?? .distantPast
            let secondAttempt = $1.lastAttemptAt ?? .distantPast
            if firstAttempt != secondAttempt {
                return firstAttempt > secondAttempt
            }
            return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
        }
    }

    func save(_ record: DailyFetchRecord) async throws {
        if let existingID = recordIDsByTaskKey[record.taskKey], existingID != record.id {
            throw RepositoryError.duplicateTaskKey
        }

        if let oldValue = records[record.id], oldValue.taskKey != record.taskKey {
            recordIDsByTaskKey[oldValue.taskKey] = nil
        }
        records[record.id] = record
        recordIDsByTaskKey[record.taskKey] = record.id
    }

    func loadSettings() async throws -> UserSettings? {
        settings
    }

    func save(_ settings: UserSettings) async throws {
        self.settings = settings
    }
}
