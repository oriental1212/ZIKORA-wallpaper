import AppKit
import Foundation
import ServiceManagement
import SwiftUI

struct ProbeMenuBarScene: Scene {
    var body: some Scene {
        MenuBarExtra("ZIKORA Probe", systemImage: "photo") {
            Text("Compile-only probe")
        }
        .menuBarExtraStyle(.menu)
    }
}

enum SystemAPIProbe {
    @MainActor
    static func run() {
        _ = NSWorkspace.shared
        _ = NSScreen.screens
        _ = SMAppService.mainApp.status

        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.didWakeNotification,
        ]
        let foundationNotifications: [Notification.Name] = [
            NSNotification.Name.NSSystemClockDidChange,
            NSNotification.Name.NSSystemTimeZoneDidChange,
        ]

        print("INFO: visible screens = \(NSScreen.screens.count)")
        print("INFO: login item status = \(SMAppService.mainApp.status.rawValue)")
        print("INFO: system notifications referenced = \(workspaceNotifications.count + foundationNotifications.count)")
        reportPass("AppKit, MenuBarExtra, ServiceManagement, and system-event API compilation")
    }
}

