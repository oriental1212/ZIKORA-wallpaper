import SwiftUI

struct DashboardView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var wallpaperMode: WallpaperMode?

    var body: some View {
        Group {
            if let services = environment.services {
                DashboardPageView(
                    commandCenter: services.commandCenter,
                    managedRootURL: services.managedRootURL,
                    wallpaperMode: wallpaperMode
                )
                .task {
                    await services.commandCenter.refresh()
                    wallpaperMode = (try? await services.repository.loadSettings())?.wallpaperMode
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .navigationTitle("dashboard.title")
    }
}

private struct DashboardPageView: View {
    @ObservedObject var commandCenter: WallpaperCommandCenter
    let managedRootURL: URL
    let wallpaperMode: WallpaperMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.section) {
                hero
                statusCards
                statusArea
            }
            .padding(DesignSpacing.section)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DesignColor.background)
        .overlay {
            if commandCenter.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(
                        cornerRadius: DesignRadius.card
                    ))
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let wallpaper = commandCenter.currentWallpaper {
            ZStack(alignment: .bottom) {
                AsyncImage(url: fileURL(for: wallpaper)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 520)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: DesignSpacing.large) {
                        heroInfo(for: wallpaper)
                        Spacer(minLength: DesignSpacing.medium)
                        heroActions
                    }

                    VStack(alignment: .leading, spacing: DesignSpacing.large) {
                        heroInfo(for: wallpaper)
                        heroActions
                    }
                }
                .padding(DesignSpacing.section)
            }
            .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 560)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .contain)
        } else {
            ZStack(alignment: .center) {
                DesignColor.elevatedSurface
                VStack(spacing: DesignSpacing.medium) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(DesignColor.secondaryText)
                        .accessibilityHidden(true)
                    Text("dashboard.empty.title")
                        .font(DesignTypography.sectionTitle)
                    Text("dashboard.empty.message")
                        .font(DesignTypography.body)
                        .foregroundStyle(DesignColor.secondaryText)
                }
                .padding(DesignSpacing.large)
            }
            .frame(maxWidth: .infinity, minHeight: 500)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var placeholder: some View {
        VStack(spacing: DesignSpacing.medium) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(DesignColor.secondaryText)
            Text("library.file-missing")
                .font(DesignTypography.body)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(DesignColor.glassSurface)
    }

    private var statusCards: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DesignSpacing.standard) {
                statusCard(
                    title: "dashboard.active-mode",
                    value: Text(
                        wallpaperMode == .slideshow
                            ? LocalizedStringKey("settings.mode-slideshow")
                            : LocalizedStringKey("settings.mode-daily")
                    ),
                    systemImage: "clock",
                    tint: DesignColor.primaryAction
                )

                statusCard(
                    title: "dashboard.today-source",
                    value: todaySourceValue,
                    systemImage: "link",
                    tint: DesignColor.secondary
                )
            }

            VStack(alignment: .leading, spacing: DesignSpacing.standard) {
                statusCard(
                    title: "dashboard.active-mode",
                    value: Text(
                        wallpaperMode == .slideshow
                            ? LocalizedStringKey("settings.mode-slideshow")
                            : LocalizedStringKey("settings.mode-daily")
                    ),
                    systemImage: "clock",
                    tint: DesignColor.primaryAction
                )

                statusCard(
                    title: "dashboard.today-source",
                    value: todaySourceValue,
                    systemImage: "link",
                    tint: DesignColor.secondary
                )
            }
        }
    }

    private func heroInfo(for wallpaper: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.small) {
            Text(wallpaper.sourceNameSnapshot)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: DesignSpacing.medium) {
                Label(wallpaper.downloadDay.rawValue, systemImage: "calendar")
                Label(
                    "\(wallpaper.pixelWidth) × \(wallpaper.pixelHeight)",
                    systemImage: "rectangle.expand.vertical"
                )
            }
            .font(DesignTypography.label)
            .foregroundStyle(.white.opacity(0.86))
        }
    }

    private var heroActions: some View {
        HStack(spacing: DesignSpacing.small) {
            DashboardHeroButton(
                title: "action.update-now",
                systemImage: "arrow.clockwise",
                isPrimary: true,
                isLoading: commandCenter.isUpdating,
                action: {
                    Task { await commandCenter.updateNow() }
                }
            )

            DashboardHeroButton(
                title: "action.next-wallpaper",
                systemImage: "shuffle",
                isPrimary: false,
                isLoading: commandCenter.isNexting,
                action: {
                    Task { await commandCenter.nextWallpaper() }
                }
            )
        }
    }

    private func statusCard(
        title: LocalizedStringKey,
        value: Text,
        systemImage: String,
        tint: Color
    ) -> some View {
        DashboardStatusCard(
            title: title,
            value: value,
            systemImage: systemImage,
            tint: tint
        )
    }

    @ViewBuilder
    private var statusArea: some View {
        if let notice = commandCenter.notice {
            StatusBadge(
                title: LocalizedStringKey(notice.message.title.rawValue),
                kind: notice.tone == .failure ? .failure : .warning
            )
            Text(LocalizedStringKey(notice.message.detail.rawValue))
                .font(DesignTypography.body)
                .foregroundStyle(DesignColor.secondaryText)
        } else if commandCenter.reusedCurrentWallpaper,
                  commandCenter.lastSucceededAt != nil {
            Label("dashboard.reused-current", systemImage: "checkmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.success)
        } else if commandCenter.lastSucceededAt != nil {
            Label("status.success", systemImage: "checkmark.circle")
                .font(DesignTypography.caption)
                .foregroundStyle(DesignColor.success)
        }
    }

    private var todaySourceValue: Text {
        if let sourceName = commandCenter.currentWallpaper?.sourceNameSnapshot {
            Text(verbatim: sourceName)
        } else {
            Text("dashboard.source-unavailable")
        }
    }

    private func fileURL(for wallpaper: Wallpaper) -> URL {
        managedRootURL.appendingPathComponent(wallpaper.relativePath.rawValue)
    }
}

private struct DashboardHeroButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isPrimary: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.small) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .lineLimit(1)
            }
            .font(DesignTypography.label)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(
                        isPrimary
                            ? DesignColor.primaryAction
                            : Color.white.opacity(0.20)
                    )
            }
            .overlay {
                if !isPrimary {
                    Capsule()
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                }
            }
            .shadow(
                color: isPrimary ? DesignColor.primaryAction.opacity(0.35) : .clear,
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

private struct DashboardStatusCard: View {
    let title: LocalizedStringKey
    let value: Text
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: DesignSpacing.standard) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(
                    cornerRadius: DesignRadius.control,
                    style: .continuous
                ))

            VStack(alignment: .leading, spacing: DesignSpacing.compact) {
                Text(title)
                    .font(DesignTypography.label)
                    .foregroundStyle(DesignColor.secondaryText)
                value
                    .font(DesignTypography.sectionTitle)
                    .foregroundStyle(DesignColor.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(DesignSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .designSurface(.card)
    }
}
