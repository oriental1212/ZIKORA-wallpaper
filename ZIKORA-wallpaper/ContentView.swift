//
//  ContentView.swift
//  ZIKORA-wallpaper
//
//  Created by Oriental on 2026/8/6.
//

import SwiftUI
import AppKit

nonisolated enum AppLaunchRouting {
    static func shouldShowAppShell(onboardingCompleted: Bool, sourceCount: Int) -> Bool {
        onboardingCompleted || sourceCount > 0
    }
}

struct ContentView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var onboardingCompleted = false
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView("status.loading")
            } else if onboardingCompleted {
                AppShellView()
            } else {
                OnboardingView {
                    onboardingCompleted = true
                }
            }
        }
        .frame(minWidth: 960, minHeight: 650)
        .background(WindowMinimumSize(minimum: CGSize(width: 960, height: 650)))
        .task {
            if let repository = environment.repository {
                let stored = try? await repository.loadSettings()
                let sources = (try? await repository.allSources()) ?? []
                onboardingCompleted = AppLaunchRouting.shouldShowAppShell(
                    onboardingCompleted: stored?.onboardingCompleted == true,
                    sourceCount: sources.count
                )
            }
            await environment.startServices()
            loaded = true
        }
    }
}

private struct WindowMinimumSize: NSViewRepresentable {
    let minimum: CGSize

    func makeNSView(context: Context) -> WindowMinimumSizeView { WindowMinimumSizeView(minimum: minimum) }
    func updateNSView(_ nsView: WindowMinimumSizeView, context: Context) { nsView.applyMinimumSize() }
}

private final class WindowMinimumSizeView: NSView {
    let minimum: CGSize

    init(minimum: CGSize) { self.minimum = minimum; super.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyMinimumSize()
    }

    func applyMinimumSize() { window?.contentMinSize = minimum }
}

#Preview {
    ContentView()
}
