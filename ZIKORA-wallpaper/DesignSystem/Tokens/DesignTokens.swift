import AppKit
import SwiftUI

enum DesignColor {
    static let background = adaptive(light: 0xF9F9FF, dark: 0x111318)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x191B21)
    static let elevatedSurface = adaptive(light: 0xF1F3FE, dark: 0x20242D)
    static let primaryAction = adaptive(light: 0x007AFF, dark: 0x0A84FF)
    static let primaryContainer = adaptive(light: 0x0070EB, dark: 0x0A5FCC)
    static let secondary = adaptive(light: 0x005AB3, dark: 0x63A8FF)
    static let critical = Color(nsColor: .systemRed)
    static let warning = Color(nsColor: .systemOrange)
    static let success = Color(nsColor: .systemGreen)
    static let primaryText = adaptive(light: 0x181C23, dark: 0xF5F6FA)
    static let secondaryText = adaptive(light: 0x414755, dark: 0xB7BDC9)
    static let separator = adaptive(light: 0xC1C6D7, dark: 0x3B404A)
    static let focus = primaryAction
    static let glassSurface = adaptiveWhite(lightAlpha: 0.72, darkAlpha: 0.12)
    static let glassBorder = adaptiveWhite(lightAlpha: 0.30, darkAlpha: 0.16)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return color(isDark ? dark : light)
        })
    }

    private static func adaptiveWhite(lightAlpha: CGFloat, darkAlpha: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let white = isDark ? CGFloat(0.08) : CGFloat(1.0)
            return NSColor(
                calibratedWhite: white,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }

    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum DesignTypography {
    static let pageTitle = Font.largeTitle.weight(.semibold)
    static let sectionTitle = Font.title2.weight(.semibold)
    static let body = Font.body
    static let label = Font.callout.weight(.medium)
    static let caption = Font.caption
    static let monospacedMetadata = Font.caption.monospacedDigit()
}

enum DesignSpacing {
    static let compact: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let large: CGFloat = 24
    static let section: CGFloat = 32
}

enum DesignRadius {
    static let control: CGFloat = 8
    static let card: CGFloat = 12
    static let pill: CGFloat = 1_000
}

enum DesignMotion {
    static let pressDuration = 0.1
    static let stateChangeDuration = 0.2
    static let progressDuration = 0.3

    static func stateChange(reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else {
            return nil
        }

        return .timingCurve(0.16, 1, 0.3, 1, duration: stateChangeDuration)
    }
}
