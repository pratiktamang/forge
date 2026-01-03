import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "000000" }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "%02X%02X%02X", r, g, b)
    }

    static func adaptive(lightHex: String, darkHex: String) -> Color {
        let dynamicColor = NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? NSColor(hex: darkHex) : NSColor(hex: lightHex)
        }

        return Color(dynamicColor)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            calibratedRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

/// Shared palette for a minimal, glass-inspired interface.
enum AppTheme {
    static let accent = color(light: "2F9C95", dark: "5ED5CD")
    static let accentShadow = color(light: "1E6D68", dark: "44AFAA")

    static let windowBackground = color(light: "F2F0EB", dark: "0F1115")
    static let sidebarBackground = color(light: "F5F3EE", dark: "17191D")
    static let sidebarHeaderBackground = color(light: "E3DFD5", dark: "1F2228")
    static let sidebarHeaderText = color(light: "5B6170", dark: "C6CCD9")
    static let sidebarRowBackground = color(light: "F9F6F0", dark: "1C1F24")
    static let sidebarDivider = color(light: "DCD6CC", dark: "272A32")

    static let contentBackground = color(light: "F7F4ED", dark: "121418")
    static let cardBackground = color(light: "FDFBF6", dark: "1B1E23")
    static let cardBorder = color(light: "E0D7C8", dark: "262A31")
    static let selectionBackground = color(light: "E8F6F4", dark: "1F2A2A")
    static let selectionBorder = color(light: "B8E5E0", dark: "365656")

    static let metadataText = color(light: "808592", dark: "9BA2B2")
    static let pillPurple = color(light: "4C5C68", dark: "7A8896")
    static let dateStampBackground = color(light: "E2F4F1", dark: "233443")

    static let quickAddBackground = color(light: "F1EDE4", dark: "1B1E22")
    static let quickAddBorder = color(light: "DDD4C6", dark: "262A31")

    static let emptyStateBorder = color(light: "DDD4C6", dark: "282C34")

    static let textPrimary = color(light: "1D1F24", dark: "F5F6FB")
    static let textSecondary = color(light: "676B75", dark: "B6BBC7")
    static let propertyHighlight = color(light: "4C7DFF", dark: "2F9C95")

    private static func color(light: String, dark: String) -> Color {
        Color.adaptive(lightHex: light, darkHex: dark)
    }
}
