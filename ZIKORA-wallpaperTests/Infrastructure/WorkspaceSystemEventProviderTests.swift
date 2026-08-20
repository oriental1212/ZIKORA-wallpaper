import AppKit
import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct WorkspaceSystemEventProviderTests {
    @Test("System notifications map to domain events")
    func mapsNotifications() {
        #expect(SystemEventNotificationMapper.event(for: NSWorkspace.didWakeNotification) == .wokeFromSleep)
        #expect(SystemEventNotificationMapper.event(for: NSApplication.didBecomeActiveNotification) == .applicationStarted)
        #expect(SystemEventNotificationMapper.event(for: .NSSystemTimeZoneDidChange) == .timeZoneChanged)
        #expect(SystemEventNotificationMapper.event(for: .NSCalendarDayChanged) == .localDayMayHaveChanged)
    }

    @Test("Unknown notifications are ignored")
    func ignoresUnknown() {
        #expect(SystemEventNotificationMapper.event(for: Notification.Name("unknown")) == nil)
    }
}
