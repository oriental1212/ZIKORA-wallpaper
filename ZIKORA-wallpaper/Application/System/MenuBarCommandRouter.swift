import Foundation

nonisolated protocol UpdateNowCommanding: Sendable {
    func updateNow() async
}

nonisolated protocol NextWallpaperCommanding: Sendable {
    func nextWallpaper() async
}

@MainActor
protocol ApplicationLifecycleControlling: Sendable {
    func openMainWindow() async
    func openSettings() async
    func shutdown() async
}

actor MenuBarCommandRouter: MenuBarCommandHandling {
    private let update: any UpdateNowCommanding
    private let next: any NextWallpaperCommanding
    private let lifecycle: any ApplicationLifecycleControlling

    init(
        update: any UpdateNowCommanding,
        next: any NextWallpaperCommanding,
        lifecycle: any ApplicationLifecycleControlling
    ) {
        self.update = update
        self.next = next
        self.lifecycle = lifecycle
    }

    func handle(_ command: MenuBarCommand) async {
        switch command {
        case .updateNow, .retry:
            await update.updateNow()
        case .nextWallpaper:
            await next.nextWallpaper()
        case .openMainWindow:
            await lifecycle.openMainWindow()
        case .openSettings:
            await lifecycle.openSettings()
        case .quit:
            await lifecycle.shutdown()
        }
    }
}

struct MenuBarStateModel: Sendable {
    private(set) var state: MenuBarPresentationState = .noCurrentWallpaper

    mutating func setCurrent(_ wallpaperID: WallpaperID?) {
        state = wallpaperID.map(MenuBarPresentationState.idle) ?? .noCurrentWallpaper
    }

    mutating func setRunning() {
        state = .running
    }

    mutating func setFailure(message: String, canRetry: Bool = true) {
        state = .failed(message: message, canRetry: canRetry)
    }
}
