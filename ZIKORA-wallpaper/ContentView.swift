//
//  ContentView.swift
//  ZIKORA-wallpaper
//
//  Created by Oriental on 2026/8/6.
//

import SwiftUI

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
                onboardingCompleted = stored?.onboardingCompleted ?? false
            }
            await environment.startServices()
            loaded = true
        }
    }
}

#Preview {
    ContentView()
}
