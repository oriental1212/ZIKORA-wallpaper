import Foundation
import ServiceManagement
import Testing
@testable import ZIKORA_wallpaper

struct SMAppLoginItemManagerTests {
    @Test("Login item toggle keeps the previous UI state after registration failure")
    func failureRollsBackState() async {
        let manager = FakeLoginItemManager(initial: .enabled, error: true)
        let coordinator = LoginItemToggleCoordinator(manager: manager)
        _ = await coordinator.synchronize()
        let status = await coordinator.setEnabled(false)
        #expect(status == .enabled)
        #expect(await manager.requestCount() == 1)
    }

    @Test("External login item changes are synchronized from the system adapter")
    func synchronizeReadsExternalState() async {
        let manager = FakeLoginItemManager(initial: .disabled)
        let coordinator = LoginItemToggleCoordinator(manager: manager)
        #expect(await coordinator.synchronize() == .disabled)
        await manager.setExternalStatus(.requiresApproval)
        #expect(await coordinator.synchronize() == .requiresApproval)
    }

    @Test("ServiceManagement statuses map to domain statuses")
    func mapsStatuses() {
        #expect(SMAppLoginItemManager.mapStatus(.enabled) == .enabled)
        #expect(SMAppLoginItemManager.mapStatus(.requiresApproval) == .requiresApproval)
        #expect(SMAppLoginItemManager.mapStatus(.notRegistered) == .disabled)
    }
}

private actor FakeLoginItemManager: LoginItemManaging {
    private var current: LoginItemStatus
    private let shouldFail: Bool
    private var requests = 0

    init(initial: LoginItemStatus, error: Bool = false) {
        current = initial
        shouldFail = error
    }

    func status() async -> LoginItemStatus { current }

    func setEnabled(_ enabled: Bool) async throws {
        requests += 1
        if shouldFail { throw TestError.failed }
        current = enabled ? .enabled : .disabled
    }

    func requestCount() -> Int { requests }
    func setExternalStatus(_ status: LoginItemStatus) { current = status }
}

private enum TestError: Error { case failed }
