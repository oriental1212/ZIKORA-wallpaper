import Foundation

nonisolated struct DailyFetchRecord: Codable, Equatable, Sendable {
    let id: DailyFetchRecordID
    let taskKey: String
    let localDay: LocalDay
    let taskKind: FetchTaskKind
    var plannedSourceID: SourceID?
    var actualSourceID: SourceID?
    var status: DailyFetchStatus
    var automaticAttemptCount: Int
    var usedDefaultSource: Bool
    var wallpaperID: WallpaperID?
    var lastAttemptAt: Date?
    var nextRetryAt: Date?
    var lastErrorCode: AppErrorCode?

    static func taskKey(for day: LocalDay, taskKind: FetchTaskKind) -> String {
        "\(day.rawValue)|\(taskKind.rawValue)"
    }

    static func pending(
        id: DailyFetchRecordID,
        day: LocalDay,
        taskKind: FetchTaskKind,
        plannedSourceID: SourceID?
    ) -> DailyFetchRecord {
        DailyFetchRecord(
            id: id,
            taskKey: taskKey(for: day, taskKind: taskKind),
            localDay: day,
            taskKind: taskKind,
            plannedSourceID: plannedSourceID,
            actualSourceID: nil,
            status: .pending,
            automaticAttemptCount: 0,
            usedDefaultSource: false,
            wallpaperID: nil,
            lastAttemptAt: nil,
            nextRetryAt: nil,
            lastErrorCode: nil
        )
    }

    func isAutomaticRetryDue(at date: Date, on day: LocalDay) -> Bool {
        taskKind == .automaticDaily
            && localDay == day
            && status == .retryScheduled
            && nextRetryAt.map { $0 <= date } == true
    }
}
