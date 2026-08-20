import Foundation

nonisolated enum WallpaperFormat: String, CaseIterable, Codable, Sendable {
    case jpeg
    case png
    case heic
    case webP = "webp"

    var preferredFileExtension: String {
        switch self {
        case .jpeg:
            "jpg"
        case .png:
            "png"
        case .heic:
            "heic"
        case .webP:
            "webp"
        }
    }
}

nonisolated enum WallpaperFileState: String, CaseIterable, Codable, Sendable {
    case available
    case missing
    case invalid
}
