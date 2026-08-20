import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct AppKitDesktopWallpaperSetterTests {
    @Test("AppKit adapter accepts only existing regular local files")
    func validatesLocalRegularFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("p06-appkit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("wallpaper.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: file)
        #expect(AppKitDesktopWallpaperSetter.isUsableWallpaperFile(file))
        #expect(!AppKitDesktopWallpaperSetter.isUsableWallpaperFile(root))
        #expect(!AppKitDesktopWallpaperSetter.isUsableWallpaperFile(URL(string: "https://example.test/image")!))
        #expect(!AppKitDesktopWallpaperSetter.isUsableWallpaperFile(root.appendingPathComponent("missing.jpg")))
    }
}
