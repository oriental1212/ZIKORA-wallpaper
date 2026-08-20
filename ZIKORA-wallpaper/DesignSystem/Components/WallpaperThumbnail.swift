import SwiftUI

enum WallpaperThumbnailState {
    case available(Image)
    case loading
    case unavailable
}

struct WallpaperThumbnail: View {
    let state: WallpaperThumbnailState
    let accessibilityLabel: LocalizedStringKey

    var body: some View {
        ZStack {
            DesignColor.surface

            switch state {
            case .available(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .unavailable:
                VStack(spacing: DesignSpacing.small) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                    Text("thumbnail.unavailable")
                        .font(DesignTypography.caption)
                }
                .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.card, style: .continuous)
                .stroke(DesignColor.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
