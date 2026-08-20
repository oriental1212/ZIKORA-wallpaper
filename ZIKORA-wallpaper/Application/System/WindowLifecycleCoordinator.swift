import Foundation

@MainActor
final class WindowLifecycleCoordinator: ApplicationLifecycleControlling {
    private let settings: any SettingsRepository
    private(set) var isWindowVisible = false
    private(set) var isApplicationActive = false
    private(set) var destination: NavigationDestination = AppDefaults.lastSelectedNavigation
    private(set) var shutdownRequested = false

    init(settings: any SettingsRepository) {
        self.settings = settings
    }

    func start(isLoginLaunch: Bool) async {
        if let saved = try? await settings.loadSettings() {
            destination = saved.lastSelectedNavigation
        }
        isWindowVisible = !isLoginLaunch
        isApplicationActive = !isLoginLaunch
    }

    func windowWillClose() {
        isWindowVisible = false
    }

    func select(_ destination: NavigationDestination) async {
        self.destination = destination
        guard var value = try? await settings.loadSettings() else { return }
        value.lastSelectedNavigation = destination
        try? await settings.save(value)
    }

    func openMainWindow() async {
        if let saved = try? await settings.loadSettings() {
            destination = saved.lastSelectedNavigation
        }
        isWindowVisible = true
        isApplicationActive = true
    }

    func openSettings() async {
        await select(.settings)
        isWindowVisible = true
        isApplicationActive = true
    }

    func shutdown() async {
        shutdownRequested = true
        isWindowVisible = false
        isApplicationActive = false
    }
}
