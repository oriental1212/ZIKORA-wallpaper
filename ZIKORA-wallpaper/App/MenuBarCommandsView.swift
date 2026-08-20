import AppKit
import SwiftUI

struct MenuBarCommandsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var commandCenter: WallpaperCommandCenter
    let services: AppServices

    var body: some View {
        Button {
            Task { await commandCenter.updateNow() }
        } label: {
            Label("action.update-now", systemImage: "arrow.clockwise")
        }
        .disabled(commandCenter.isRunning)

        Button {
            Task { await commandCenter.nextWallpaper() }
        } label: {
            Label("action.next-wallpaper", systemImage: "photo.on.rectangle")
        }
        .disabled(commandCenter.isRunning)

        if commandCenter.isRunning {
            Text("status.loading")
        } else if let notice = commandCenter.notice {
            Text(LocalizedStringKey(notice.message.title.rawValue))
        } else if let wallpaper = commandCenter.currentWallpaper {
            Text(wallpaper.sourceNameSnapshot)
                .lineLimit(1)
        }

        Divider()

        Button {
            Task {
                await services.lifecycle.openMainWindow()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            Label("menu.open-dashboard", systemImage: "rectangle.grid.2x2")
        }

        Button {
            Task {
                await services.lifecycle.openSettings()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            Label("menu.settings", systemImage: "gearshape")
        }

        Divider()

        Button("menu.quit") {
            Task {
                await services.shutdown()
                NSApp.terminate(nil)
            }
        }
    }
}
