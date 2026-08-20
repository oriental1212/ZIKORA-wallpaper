import SwiftUI

enum SourceStatusDisplay: Equatable {
    case never
    case loading
    case success
    case offline
    case failed
    case warning
    case disabled

    init(source: WallpaperSource) {
        guard source.isEnabled else {
            self = .disabled
            return
        }
        if source.consecutiveFailureDays >= 3 {
            self = .warning
            return
        }
        switch source.lastFetchStatus {
        case .never:
            self = .never
        case .loading:
            self = .loading
        case .success:
            self = .success
        case .offline:
            self = .offline
        case .failed:
            self = .failed
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .never:
            "sources.status.never"
        case .loading:
            "sources.status.loading"
        case .success:
            "sources.status.success"
        case .offline:
            "sources.status.offline"
        case .failed:
            "sources.status.failed"
        case .warning:
            "sources.status.warning"
        case .disabled:
            "sources.status.disabled"
        }
    }

    var systemImage: String {
        switch self {
        case .never:
            "circle.dashed"
        case .loading:
            "arrow.triangle.2.circlepath"
        case .success:
            "checkmark.circle"
        case .offline:
            "wifi.slash"
        case .failed:
            "xmark.octagon"
        case .warning:
            "exclamationmark.triangle"
        case .disabled:
            "pause.circle"
        }
    }

    var color: Color {
        switch self {
        case .never, .loading:
            DesignColor.secondaryText
        case .success:
            DesignColor.success
        case .offline, .warning:
            DesignColor.warning
        case .failed:
            DesignColor.critical
        case .disabled:
            DesignColor.secondaryText
        }
    }
}

struct SourceStatusView: View {
    let source: WallpaperSource

    var body: some View {
        let status = SourceStatusDisplay(source: source)
        Label(status.title, systemImage: status.systemImage)
            .font(DesignTypography.caption.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, DesignSpacing.medium)
            .padding(.vertical, DesignSpacing.compact)
            .background(status.color.opacity(0.1), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

extension Weekday {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .monday:
            "weekday.monday"
        case .tuesday:
            "weekday.tuesday"
        case .wednesday:
            "weekday.wednesday"
        case .thursday:
            "weekday.thursday"
        case .friday:
            "weekday.friday"
        case .saturday:
            "weekday.saturday"
        case .sunday:
            "weekday.sunday"
        }
    }

    var deletionName: String {
        switch self {
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        case .sunday:
            "Sunday"
        }
    }
}

extension UserMessageKey {
    var text: Text {
        Text(LocalizedStringKey(rawValue))
    }
}

extension ByteCountFormatter {
    static let sourcePreview: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

func sourceFormatIdentifier(_ identifier: String) -> String {
    switch identifier {
    case "public.png":
        return "PNG"
    case "public.jpeg":
        return "JPEG"
    case "public.heic", "public.heif":
        return "HEIC"
    case "org.webmproject.webp", "public.webp":
        return "WebP"
    default:
        return identifier.uppercased()
    }
}
