//
//  ZIKORA_wallpaperApp.swift
//  ZIKORA-wallpaper
//
//  Created by Oriental on 2026/8/6.
//

import SwiftUI
import AppKit

@main
struct ZIKORA_wallpaperApp: App {
    @State private var environment: AppEnvironment
    @State private var persistence: PersistenceStartupController

    init() {
        let environment = AppEnvironment.live()
        let persistence = PersistenceStartupController.live(
            logger: environment.logger
        )

        if case .ready = persistence.phase,
           let container = persistence.modelContainer,
           let managedRootURL = persistence.managedRootURL {
            environment.configurePersistentStore(
                container: container,
                managedRootURL: managedRootURL
            )
        }

        _environment = State(initialValue: environment)
        _persistence = State(initialValue: persistence)
    }

    var body: some Scene {
        WindowGroup("ZIKORA", id: "main") {
            Group {
                switch persistence.phase {
                case .ready:
                    ContentView()
                        .task {
                            await environment.startServices()
                        }
                case .recoveryRequired(let message):
                    PersistenceRecoveryView(
                        message: message,
                        retry: persistence.retry,
                        archiveAndStartFresh: persistence.archiveAndStartFresh
                    )
                }
            }
            .environment(\.appEnvironment, environment)
        }
        .defaultSize(width: 1000, height: 700)
        .commands { CommandGroup(replacing: .newItem) { } }

        MenuBarExtra("ZIKORA", systemImage: "photo.on.rectangle.angled") {
            if let services = environment.services {
                MenuBarCommandsView(
                    commandCenter: services.commandCenter,
                    services: services
                )
            } else {
                Button("menu.open-dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
