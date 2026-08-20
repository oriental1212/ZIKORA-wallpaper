import Foundation
import ServiceManagement

final class SMAppLoginItemManager: LoginItemManaging, @unchecked Sendable {
    func status() async -> LoginItemStatus {
        Self.mapStatus(SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) async throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try await SMAppService.mainApp.unregister()
        }
    }

    static func mapStatus(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notRegistered:
            .disabled
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }
}

actor LoginItemToggleCoordinator {
    private let manager: any LoginItemManaging
    private(set) var status: LoginItemStatus = .unavailable

    init(manager: any LoginItemManaging) {
        self.manager = manager
    }

    func synchronize() async -> LoginItemStatus {
        status = await manager.status()
        return status
    }

    func setEnabled(_ enabled: Bool) async -> LoginItemStatus {
        let previous = status
        do {
            try await manager.setEnabled(enabled)
            status = await manager.status()
        } catch {
            status = previous
        }
        return status
    }
}
