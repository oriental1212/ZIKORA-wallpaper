import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct MenuBarCommandRouterTests {
    @Test("Menu bar routes update and next through shared commands")
    func routesSharedCommands() async {
        let update = RecordingMenuCommand()
        let next = RecordingMenuCommand()
        let lifecycle = RecordingLifecycleCommand()
        let router = MenuBarCommandRouter(update: update, next: next, lifecycle: lifecycle)

        await router.handle(.updateNow)
        await router.handle(.retry)
        await router.handle(.nextWallpaper)
        #expect(await update.calls() == [.updateNow, .updateNow])
        #expect(await next.calls() == [.nextWallpaper])
    }

    @Test("Menu bar routes window, settings, and shutdown commands")
    func routesLifecycleCommands() async {
        let lifecycle = RecordingLifecycleCommand()
        let router = MenuBarCommandRouter(
            update: RecordingMenuCommand(), next: RecordingMenuCommand(), lifecycle: lifecycle
        )
        await router.handle(.openMainWindow)
        await router.handle(.openSettings)
        await router.handle(.quit)
        #expect(await lifecycle.calls() == [.openMainWindow, .openSettings, .shutdown])
    }

    @Test("Menu bar state model covers no current, running, idle, and failure")
    func stateModel() {
        var model = MenuBarStateModel()
        #expect(model.state == .noCurrentWallpaper)
        model.setRunning()
        #expect(model.state == .running)
        let wallpaperID = WallpaperID(rawValue: UUID())
        model.setCurrent(wallpaperID)
        #expect(model.state == .idle(currentWallpaperID: wallpaperID))
        model.setFailure(message: "failed")
        #expect(model.state == .failed(message: "failed", canRetry: true))
    }
}

private actor RecordingMenuCommand: UpdateNowCommanding, NextWallpaperCommanding {
    private var recorded: [MenuBarCommand] = []
    func updateNow() async { recorded.append(.updateNow) }
    func nextWallpaper() async { recorded.append(.nextWallpaper) }
    func calls() -> [MenuBarCommand] { recorded }
}

@MainActor
private final class RecordingLifecycleCommand: ApplicationLifecycleControlling {
    private var recorded: [LifecycleCall] = []
    func openMainWindow() async { recorded.append(.openMainWindow) }
    func openSettings() async { recorded.append(.openSettings) }
    func shutdown() async { recorded.append(.shutdown) }
    func calls() -> [LifecycleCall] { recorded }
}

private enum LifecycleCall: Equatable, Sendable {
    case openMainWindow
    case openSettings
    case shutdown
}
