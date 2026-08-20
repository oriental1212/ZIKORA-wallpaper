import AppKit
import Foundation
import Network

final class WorkspaceSystemEventProvider: SystemEventProviding, @unchecked Sendable {
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    func events() -> AsyncStream<SystemEvent> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "cn.zhikezhui.ZIKORA.system-events")
            let registry = ObserverRegistry(center: center, monitor: monitor)

            registry.add(name: NSWorkspace.didWakeNotification) {
                continuation.yield(.wokeFromSleep)
            }
            registry.add(name: NSWorkspace.willSleepNotification) {
                continuation.yield(.localDayMayHaveChanged)
            }
            registry.add(name: NSApplication.didBecomeActiveNotification) {
                continuation.yield(.applicationStarted)
            }
            registry.add(name: .NSSystemTimeZoneDidChange) {
                continuation.yield(.timeZoneChanged)
            }
            registry.add(name: .NSCalendarDayChanged) {
                continuation.yield(.localDayMayHaveChanged)
            }

            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    continuation.yield(.networkBecameAvailable)
                }
            }
            monitor.start(queue: queue)
            continuation.onTermination = { @Sendable _ in
                registry.cancel()
            }
        }
    }
}

nonisolated private final class ObserverRegistry: @unchecked Sendable {
    private let center: NotificationCenter
    private let monitor: NWPathMonitor
    private var tokens: [NSObjectProtocol] = []
    private let lock = NSLock()

    init(center: NotificationCenter, monitor: NWPathMonitor) {
        self.center = center
        self.monitor = monitor
    }

    func add(name: Notification.Name, action: @escaping @Sendable () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: nil) { _ in
            action()
        }
        lock.lock()
        tokens.append(token)
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let currentTokens = tokens
        tokens.removeAll()
        lock.unlock()
        currentTokens.forEach(center.removeObserver)
        monitor.cancel()
    }
}

enum SystemEventNotificationMapper {
    static func event(for name: Notification.Name) -> SystemEvent? {
        switch name {
        case NSWorkspace.didWakeNotification:
            .wokeFromSleep
        case NSWorkspace.willSleepNotification:
            .localDayMayHaveChanged
        case NSApplication.didBecomeActiveNotification:
            .applicationStarted
        case .NSSystemTimeZoneDidChange:
            .timeZoneChanged
        case .NSCalendarDayChanged:
            .localDayMayHaveChanged
        default:
            nil
        }
    }
}
