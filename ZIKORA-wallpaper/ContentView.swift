//
//  ContentView.swift
//  ZIKORA-wallpaper
//
//  Created by Oriental on 2026/8/6.
//

import SwiftUI

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
        .frame(minWidth: 800, minHeight: 560)
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

#Preview {
    ContentView()
}
