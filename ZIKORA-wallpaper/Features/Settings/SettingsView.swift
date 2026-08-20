import SwiftUI

struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: SettingsViewModel?

    var body: some View {
        Group {
            if let model {
                SettingsPageView(model: model)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await prepareModel()
        }
        .navigationTitle("settings.title")
    }

    @MainActor
    private func prepareModel() async {
        guard model == nil, let services = environment.services else {
            return
        }
        let viewModel = SettingsViewModel(
            repository: services.repository,
            loginItemCoordinator: services.loginItemCoordinator,
            rotationScheduler: services.rotationScheduler,
            fileStore: services.fileStore,
            fileInventory: services.fileInventory,
            cacheInspector: services.cacheInspector,
            finder: services.finder,
            clock: environment.clock,
            calendar: environment.calendar,
            uuidGenerator: environment.uuidGenerator
        )
        model = viewModel
        await viewModel.load()
    }
}

private struct SettingsPageView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        ScrollView {
            Form {
                generalSection
                rotationSection
                storageSection
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tint(DesignColor.primaryAction)
            .padding(DesignSpacing.section)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignColor.background)
        .confirmationDialog(
            "settings.cleanup.title",
            isPresented: Binding(
                get: { model.pendingCleanupConfirmation },
                set: { if !$0 { model.pendingCleanupConfirmation = false } }
            ),
            titleVisibility: .visible
        ) {
            Button("settings.cleanup.confirm", role: .destructive) {
                Task { await model.confirmCleanup() }
            }
            Button("action.cancel", role: .cancel) {
                model.pendingCleanupConfirmation = false
            }
        } message: {
            if let estimate = model.cleanupEstimate {
                Text("settings.cleanup-prefix") + Text(verbatim: cleanupDetail(for: estimate))
            } else {
                Text("settings.cleanup-no-estimate")
            }
        }
    }

    private var generalSection: some View {
        Section("settings.general") {
            Toggle("settings.launch-at-login", isOn: launchAtLoginBinding)
            if model.loginItemStatus == .requiresApproval {
                Label("settings.login-requires-approval", systemImage: "exclamationmark.triangle")
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColor.warning)
            } else if model.loginItemStatus == .unavailable {
                Label("settings.login-unavailable", systemImage: "xmark.octagon")
                    .font(DesignTypography.caption)
                    .foregroundStyle(DesignColor.critical)
            }
        }
    }

    private var rotationSection: some View {
        Section("settings.rotation") {
            Picker("settings.wallpaper-mode", selection: wallpaperModeBinding) {
                Text("settings.mode-daily").tag(WallpaperMode.daily)
                Text("settings.mode-slideshow").tag(WallpaperMode.slideshow)
            }

            if model.settings?.wallpaperMode == .slideshow {
                Picker("settings.slideshow-order", selection: slideshowOrderBinding) {
                    Text("settings.order-random").tag(SlideshowOrder.random)
                    Text("settings.order-chronological").tag(SlideshowOrder.chronological)
                }
                Picker("settings.slideshow-interval", selection: slideshowIntervalBinding) {
                    ForEach(SlideshowInterval.allCases, id: \.self) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                if model.slideShowCandidateCount == 0 {
                    Label("settings.no-candidates", systemImage: "exclamationmark.triangle")
                        .font(DesignTypography.caption)
                        .foregroundStyle(DesignColor.warning)
                }
            }
        }
    }

    private var storageSection: some View {
        Section("settings.storage") {
            Picker("settings.retention", selection: retentionBinding) {
                ForEach(RetentionPolicy.allCases, id: \.self) { policy in
                    Text(policy.title).tag(policy)
                }
            }
            if let location = model.cacheLocation {
                LabeledContent {
                    Text(location.displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } label: {
                    Text("settings.cache-location")
                }
            }
            if let statistics = model.storageStatistics {
                LabeledContent(
                    "settings.cache-size",
                    value: ByteCountFormatter.sourcePreview.string(fromByteCount: statistics.byteCount)
                )
            }
            if let estimate = model.cleanupEstimate {
                LabeledContent(
                    "settings.cleanup-estimate",
                    value: "\(estimate.itemCount) · \(ByteCountFormatter.sourcePreview.string(fromByteCount: estimate.byteCount))"
                )
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("settings.open-cache") {
                        Task { await model.openCacheDirectory() }
                    }
                    Spacer()
                    ZIKORAButton(
                        "settings.cleanup",
                        systemImage: "trash",
                        role: .destructive,
                        disabledReason: model.cleanupEstimate == nil ? "settings.cleanup-unavailable" : nil,
                        action: { Task { await model.requestCleanup() } }
                    )
                }

                VStack(alignment: .leading, spacing: DesignSpacing.small) {
                    Button("settings.open-cache") {
                        Task { await model.openCacheDirectory() }
                    }
                    ZIKORAButton(
                        "settings.cleanup",
                        systemImage: "trash",
                        role: .destructive,
                        disabledReason: model.cleanupEstimate == nil ? "settings.cleanup-unavailable" : nil,
                        action: { Task { await model.requestCleanup() } }
                    )
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("settings.about") {
            LabeledContent(
                "settings.app-name",
                value: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ZIKORA"
            )
            LabeledContent(
                "settings.version",
                value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            )
            Text("settings.privacy")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.settings?.launchAtLogin ?? AppDefaults.launchAtLogin },
            set: { value in Task { await model.setLaunchAtLogin(value) } }
        )
    }

    private var wallpaperModeBinding: Binding<WallpaperMode> {
        Binding(
            get: { model.settings?.wallpaperMode ?? AppDefaults.wallpaperMode },
            set: { value in Task { await model.setWallpaperMode(value) } }
        )
    }

    private var slideshowOrderBinding: Binding<SlideshowOrder> {
        Binding(
            get: { model.settings?.slideshowOrder ?? AppDefaults.slideshowOrder },
            set: { value in Task { await model.setSlideshowOrder(value) } }
        )
    }

    private var slideshowIntervalBinding: Binding<SlideshowInterval> {
        Binding(
            get: { model.settings?.slideshowInterval ?? AppDefaults.slideshowInterval },
            set: { value in Task { await model.setSlideshowInterval(value) } }
        )
    }

    private var retentionBinding: Binding<RetentionPolicy> {
        Binding(
            get: { model.settings?.retentionPolicy ?? AppDefaults.retentionPolicy },
            set: { value in Task { await model.setRetentionPolicy(value) } }
        )
    }

    private func cleanupDetail(for estimate: WallpaperCleanupEstimate) -> String {
        let size = ByteCountFormatter.sourcePreview.string(fromByteCount: estimate.byteCount)
        return "\(estimate.itemCount) · \(size)"
    }
}

private extension SlideshowInterval {
    var title: LocalizedStringKey {
        switch self {
        case .fiveMinutes: "settings.interval-5m"
        case .fifteenMinutes: "settings.interval-15m"
        case .thirtyMinutes: "settings.interval-30m"
        case .oneHour: "settings.interval-1h"
        case .threeHours: "settings.interval-3h"
        case .sixHours: "settings.interval-6h"
        case .twelveHours: "settings.interval-12h"
        case .oneDay: "settings.interval-1d"
        }
    }
}

private extension RetentionPolicy {
    var title: LocalizedStringKey {
        switch self {
        case .sevenDays: "settings.retention-7"
        case .fourteenDays: "settings.retention-14"
        case .thirtyDays: "settings.retention-30"
        case .sixtyDays: "settings.retention-60"
        case .ninetyDays: "settings.retention-90"
        case .forever: "settings.retention-forever"
        }
    }
}
