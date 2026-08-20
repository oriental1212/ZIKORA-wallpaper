import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct WindowLifecycleCoordinatorTests {
    @Test("Login launch stays hidden while normal launch opens the saved page")
    func launchVisibility() async throws {
        var settings = UserSettings.defaults(id: UUID(), updatedAt: Date())
        settings.lastSelectedNavigation = .library
        let repository = try InMemoryRepositoryStore(settings: settings)
        let coordinator = WindowLifecycleCoordinator(settings: repository)

        await coordinator.start(isLoginLaunch: true)
        #expect(coordinator.isWindowVisible == false)
        #expect(coordinator.destination == .library)
        await coordinator.openMainWindow()
        #expect(coordinator.isWindowVisible)
        #expect(coordinator.isApplicationActive)

        coordinator.windowWillClose()
        #expect(coordinator.isWindowVisible == false)
    }

    @Test("Navigation selection persists and settings can be opened from Menu Bar")
    func persistsNavigation() async throws {
        let repository = try InMemoryRepositoryStore(
            settings: UserSettings.defaults(id: UUID(), updatedAt: Date())
        )
        let coordinator = WindowLifecycleCoordinator(settings: repository)

        await coordinator.select(.sources)
        await coordinator.openSettings()
        #expect(coordinator.destination == .settings)
        #expect(try await repository.loadSettings()?.lastSelectedNavigation == .settings)
    }

    @Test("Shutdown clears visibility and requests unified termination")
    func shutdown() async throws {
        let repository = try InMemoryRepositoryStore()
        let coordinator = WindowLifecycleCoordinator(settings: repository)
        await coordinator.start(isLoginLaunch: false)
        await coordinator.shutdown()
        #expect(coordinator.shutdownRequested)
        #expect(coordinator.isWindowVisible == false)
        #expect(coordinator.isApplicationActive == false)
    }
}
