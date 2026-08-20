import SwiftUI

struct AppShellView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var selection: NavigationDestination = AppDefaults.lastSelectedNavigation
    @State private var settings: UserSettings?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                sidebarBrand

                List(NavigationDestination.allCases, id: \.self, selection: $selection) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .accessibilityLabel(Text(destination.title))
                        .tag(destination)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .tint(DesignColor.primaryAction)
            .background {
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(DesignColor.background.opacity(0.55))
            }
            .frame(minWidth: 190)
        } detail: {
            NavigationStack {
                Group {
                    switch selection {
                    case .dashboard:
                        DashboardView()
                    case .sources:
                        SourcesView()
                    case .library:
                        LibraryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            if let repository = environment.repository {
                settings = try? await repository.loadSettings()
            }
            if let saved = settings?.lastSelectedNavigation { selection = saved }
        }
        .onChange(of: selection) { _, value in
            Task { await persist(selection: value) }
        }
    }

    private var sidebarBrand: some View {
        HStack(spacing: DesignSpacing.medium) {
            Image("ZIKORALogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.control, style: .continuous))
                .accessibilityLabel("ZIKORA")

            VStack(alignment: .leading, spacing: 1) {
                Text("ZIKORA")
                    .font(.headline.weight(.semibold))
                Text(verbatim: "ZIKORA-wallpaper")
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .padding(.horizontal, DesignSpacing.large)
        .padding(.top, DesignSpacing.large)
        .padding(.bottom, DesignSpacing.medium)
    }

    private func persist(selection: NavigationDestination) async {
        guard let repository = environment.repository else { return }
        var value = settings ?? UserSettings.defaults(id: UUID(), updatedAt: Date())
        value.lastSelectedNavigation = selection
        value.updatedAt = Date()
        try? await repository.save(value)
        settings = value
    }
}

private extension NavigationDestination {
    var title: LocalizedStringKey {
        switch self {
        case .dashboard: "nav.dashboard"
        case .sources: "nav.sources"
        case .library: "nav.library"
        case .settings: "nav.settings"
        }
    }

    var systemImage: String {
        switch self { case .dashboard: "rectangle.grid.2x2"; case .sources: "link"; case .library: "photo.on.rectangle"; case .settings: "gearshape" }
    }
}
