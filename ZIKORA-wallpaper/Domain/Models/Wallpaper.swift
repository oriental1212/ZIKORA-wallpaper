import Foundation

nonisolated struct Wallpaper: Codable, Equatable, Sendable {
    let id: WallpaperID
    let contentHash: String
    var sourceID: SourceID?
    let sourceNameSnapshot: String
    var relativePath: ManagedRelativePath
    let downloadDay: LocalDay
    let createdAt: Date
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var format: WallpaperFormat
    var fileState: WallpaperFileState
    var isCurrent: Bool
}
