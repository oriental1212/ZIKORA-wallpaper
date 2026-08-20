import Foundation

nonisolated enum WallpaperSelectionPolicy {
    static func chronological(_ wallpapers: [Wallpaper]) -> [Wallpaper] {
        wallpapers
            .filter { $0.fileState == .available }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
    }

    static func manualDaily(_ wallpapers: [Wallpaper]) -> [Wallpaper] {
        wallpapers
            .filter { $0.fileState == .available }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.rawValue.uuidString > rhs.id.rawValue.uuidString
            }
    }

    static func randomPool(
        _ wallpapers: [Wallpaper],
        previousID: WallpaperID? = nil
    ) -> [Wallpaper] {
        let available = wallpapers.filter { $0.fileState == .available && !$0.isCurrent }
        guard let previousID, available.count > 1 else { return available }
        let withoutPrevious = available.filter { $0.id != previousID }
        return withoutPrevious.isEmpty ? available : withoutPrevious
    }

    static func selectRandom(
        _ wallpapers: [Wallpaper],
        previousID: WallpaperID? = nil,
        selector: any RandomSelecting
    ) async -> Wallpaper? {
        let pool = randomPool(wallpapers, previousID: previousID)
        guard let index = await selector.index(upperBound: pool.count), pool.indices.contains(index) else {
            return nil
        }
        return pool[index]
    }
}
