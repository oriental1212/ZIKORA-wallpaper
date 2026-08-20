import Foundation

nonisolated enum WallpaperCleanupReason: String, Sendable, Equatable {
    case retentionExpired
    case damaged
}

nonisolated struct WallpaperCleanupCandidate: Sendable, Equatable {
    let wallpaperID: WallpaperID
    let relativePath: ManagedRelativePath
    let fileSize: Int64
    let reasons: Set<WallpaperCleanupReason>
}

nonisolated struct WallpaperCleanupEstimate: Sendable, Equatable {
    let candidates: [WallpaperCleanupCandidate]
    let orphanPaths: [ManagedRelativePath]

    var itemCount: Int { candidates.count + orphanPaths.count }

    var byteCount: Int64 {
        candidates.reduce(into: Int64(0)) { total, candidate in
            total += candidate.fileSize
        }
    }
}

nonisolated struct WallpaperCleanupReport: Sendable, Equatable {
    let deletedWallpaperIDs: [WallpaperID]
    let deletedOrphanPaths: [ManagedRelativePath]
    let failedWallpaperIDs: [WallpaperID]
    let failedPaths: [ManagedRelativePath]
    let remainingStatistics: FileStoreStatistics?

    var deletedItemCount: Int {
        deletedWallpaperIDs.count + deletedOrphanPaths.count
    }

    var hasFailures: Bool {
        !failedWallpaperIDs.isEmpty || !failedPaths.isEmpty
    }
}

nonisolated enum WallpaperCleanupExecutionError: Error, Equatable, Sendable {
    case confirmationRequired
}

/// Pure planning boundary for retention and damaged-record cleanup.
nonisolated enum WallpaperCleanupPlanner {
    static func estimate(
        wallpapers: [Wallpaper],
        inventory: Set<ManagedRelativePath>,
        today: LocalDay,
        policy: RetentionPolicy,
        calendar: Calendar
    ) -> WallpaperCleanupEstimate {
        let cutoffDay: LocalDay?
        if let dayCount = policy.dayCount {
            cutoffDay = Self.cutoffDay(
                from: today,
                subtracting: dayCount,
                calendar: calendar
            )
        } else {
            cutoffDay = nil
        }
        let candidates = wallpapers.compactMap { wallpaper -> WallpaperCleanupCandidate? in
            guard !wallpaper.isCurrent else { return nil }
            var reasons = Set<WallpaperCleanupReason>()
            if wallpaper.fileState == .missing || wallpaper.fileState == .invalid {
                reasons.insert(.damaged)
            }
            if let cutoffDay, wallpaper.downloadDay < cutoffDay {
                reasons.insert(.retentionExpired)
            }
            guard !reasons.isEmpty else { return nil }
            return WallpaperCleanupCandidate(
                wallpaperID: wallpaper.id,
                relativePath: wallpaper.relativePath,
                fileSize: wallpaper.fileState == .available ? wallpaper.fileSize : 0,
                reasons: reasons
            )
        }
        .sorted { $0.wallpaperID.rawValue.uuidString < $1.wallpaperID.rawValue.uuidString }

        let knownPaths = Set(wallpapers.map(\.relativePath))
        let orphanPaths = inventory.subtracting(knownPaths).sorted {
            $0.rawValue < $1.rawValue
        }
        return WallpaperCleanupEstimate(candidates: candidates, orphanPaths: orphanPaths)
    }

    private static func cutoffDay(
        from today: LocalDay,
        subtracting dayCount: Int,
        calendar: Calendar
    ) -> LocalDay? {
        let parts = today.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        guard let todayDate = calendar.date(from: components),
              let cutoffDate = calendar.date(
                  byAdding: .day,
                  value: -dayCount,
                  to: todayDate
              ) else { return nil }
        return LocalDay(containing: cutoffDate, calendar: calendar)
    }
}

nonisolated struct CleanupWallpapersUseCase: Sendable {
    private let wallpapers: any WallpaperRepository
    private let fileStore: any WallpaperFileStore
    private let fileInventory: any ManagedFileInventoryProviding

    init(
        wallpapers: any WallpaperRepository,
        fileStore: any WallpaperFileStore,
        fileInventory: any ManagedFileInventoryProviding
    ) {
        self.wallpapers = wallpapers
        self.fileStore = fileStore
        self.fileInventory = fileInventory
    }

    func estimate(
        policy: RetentionPolicy,
        today: LocalDay,
        calendar: Calendar
    ) async throws -> WallpaperCleanupEstimate {
        let records = try await wallpapers.allWallpapers()
        let inventory = try await fileInventory.inventory()
        return WallpaperCleanupPlanner.estimate(
            wallpapers: records,
            inventory: inventory,
            today: today,
            policy: policy,
            calendar: calendar
        )
    }

    func execute(
        policy: RetentionPolicy,
        today: LocalDay,
        calendar: Calendar,
        confirmed: Bool
    ) async throws -> WallpaperCleanupReport {
        guard confirmed else {
            throw WallpaperCleanupExecutionError.confirmationRequired
        }
        let estimate = try await estimate(policy: policy, today: today, calendar: calendar)
        var deletedWallpaperIDs: [WallpaperID] = []
        var deletedOrphanPaths: [ManagedRelativePath] = []
        var failedWallpaperIDs: [WallpaperID] = []
        var failedPaths: [ManagedRelativePath] = []

        for candidate in estimate.candidates {
            do {
                try await fileStore.remove(relativePath: candidate.relativePath.rawValue)
                try await wallpapers.delete(id: candidate.wallpaperID)
                deletedWallpaperIDs.append(candidate.wallpaperID)
            } catch {
                failedWallpaperIDs.append(candidate.wallpaperID)
            }
        }

        for path in estimate.orphanPaths {
            do {
                try await fileStore.remove(relativePath: path.rawValue)
                deletedOrphanPaths.append(path)
            } catch {
                failedPaths.append(path)
            }
        }

        let remainingStatistics = try? await fileStore.statistics()

        return WallpaperCleanupReport(
            deletedWallpaperIDs: deletedWallpaperIDs.sorted(by: Self.sortIDs),
            deletedOrphanPaths: deletedOrphanPaths.sorted { $0.rawValue < $1.rawValue },
            failedWallpaperIDs: failedWallpaperIDs.sorted(by: Self.sortIDs),
            failedPaths: failedPaths.sorted { $0.rawValue < $1.rawValue },
            remainingStatistics: remainingStatistics
        )
    }

    private static func sortIDs(_ lhs: WallpaperID, _ rhs: WallpaperID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}
