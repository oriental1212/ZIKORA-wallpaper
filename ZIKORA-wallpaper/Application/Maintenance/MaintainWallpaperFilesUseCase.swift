import Foundation

nonisolated struct WallpaperMaintenanceReport: Equatable, Sendable {
    let inspectedRecordCount: Int
    let missingRecordIDs: [WallpaperID]
    let restoredRecordIDs: [WallpaperID]
    let unknownRelativePaths: [ManagedRelativePath]

    var hasInconsistencies: Bool {
        !missingRecordIDs.isEmpty || !restoredRecordIDs.isEmpty || !unknownRelativePaths.isEmpty
    }
}

nonisolated struct MaintainWallpaperFilesUseCase: Sendable {
    private let wallpapers: any WallpaperRepository
    private let fileInventory: any ManagedFileInventoryProviding
    private let logger: any AppLogging

    init(
        wallpapers: any WallpaperRepository,
        fileInventory: any ManagedFileInventoryProviding,
        logger: any AppLogging
    ) {
        self.wallpapers = wallpapers
        self.fileInventory = fileInventory
        self.logger = logger
    }

    func execute() async throws -> WallpaperMaintenanceReport {
        let records = try await wallpapers.allWallpapers()
        let files = try await fileInventory.inventory()
        let knownPaths = Set(records.map(\.relativePath))
        var missingRecordIDs: [WallpaperID] = []
        var restoredRecordIDs: [WallpaperID] = []

        for record in records {
            if files.contains(record.relativePath) {
                if record.fileState == .missing {
                    try await wallpapers.markFileState(id: record.id, state: .available)
                    restoredRecordIDs.append(record.id)
                }
            } else {
                missingRecordIDs.append(record.id)
                if record.fileState != .missing {
                    try await wallpapers.markFileState(id: record.id, state: .missing)
                }
            }
        }

        let unknownRelativePaths = files
            .subtracting(knownPaths)
            .sorted { $0.rawValue < $1.rawValue }
        let report = WallpaperMaintenanceReport(
            inspectedRecordCount: records.count,
            missingRecordIDs: missingRecordIDs.sorted(by: Self.sortIDs),
            restoredRecordIDs: restoredRecordIDs.sorted(by: Self.sortIDs),
            unknownRelativePaths: unknownRelativePaths
        )

        logger.log(AppLogRecord(
            category: .fileStore,
            level: report.hasInconsistencies ? .warning : .information,
            event: report.hasInconsistencies ? .inconsistencyDetected : .operationSucceeded
        ))
        return report
    }

    private static func sortIDs(_ lhs: WallpaperID, _ rhs: WallpaperID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}
