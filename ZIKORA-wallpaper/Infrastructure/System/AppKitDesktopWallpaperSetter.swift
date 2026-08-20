import AppKit
import Foundation

/// AppKit boundary for applying one already-verified local file to every connected display.
final class AppKitDesktopWallpaperSetter: DesktopWallpaperSetting, @unchecked Sendable {
    func setWallpaper(fileURL: URL) async -> [DisplayWallpaperResult] {
        await MainActor.run {
            guard Self.isUsableWallpaperFile(fileURL) else { return [] }
            return NSScreen.screens.map { screen in
                let displayID = Self.displayID(for: screen)
                do {
                    try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [:])
                    return DisplayWallpaperResult(displayID: displayID, succeeded: true)
                } catch {
                    return DisplayWallpaperResult(displayID: displayID, succeeded: false)
                }
            }
        }
    }

    static func isUsableWallpaperFile(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard url.isFileURL else { return false }
        let standardized = url.standardizedFileURL
        guard fileManager.fileExists(atPath: standardized.path) else { return false }
        guard let values = try? standardized.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    @MainActor
    private static func displayID(for screen: NSScreen) -> DisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return DisplayID(rawValue: number.stringValue)
        }
        return DisplayID(rawValue: screen.localizedName)
    }
}
