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
        return Color(dynamicColor ?? NSColor(hex: lightHex))
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

/// Shared palette inspired by the reference mail client's warm, papery UI.
enum AppTheme {
    static let accent = color(light: "DA7560", dark: "F29D89")
    static let accentShadow = color(light: "C16754", dark: "E27F68")

    static let windowBackground = color(light: "F6F1EB", dark: "1E1A18")
    static let sidebarBackground = color(light: "F1E8DF", dark: "191513")
    static let sidebarHeaderBackground = color(light: "FFE1CB", dark: "3B2C24")
    static let sidebarHeaderText = color(light: "9B6E53", dark: "F3D7C1")
    static let sidebarRowBackground = color(light: "FBF8F3", dark: "221B19")
    static let sidebarDivider = color(light: "E7D9CD", dark: "372C27")

    static let contentBackground = color(light: "FCFAF6", dark: "1D1917")
    static let cardBackground = color(light: "FFFFFF", dark: "2A221F")
    static let cardBorder = color(light: "E6DBD0", dark: "3B2F2A")
    static let selectionBackground = color(light: "EFE0D5", dark: "3A2A25")
    static let selectionBorder = color(light: "D8C0B1", dark: "4B3730")

    static let metadataText = color(light: "9D9086", dark: "BAAAA0")
    static let pillPurple = color(light: "7443D8", dark: "A58CFF")
    static let dateStampBackground = color(light: "E3E0FB", dark: "3C3360")

    static let quickAddBackground = color(light: "F0E6DA", dark: "2A221C")
    static let quickAddBorder = color(light: "E1D4C7", dark: "40342D")

    static let emptyStateBorder = color(light: "E8DCD0", dark: "3B2F28")

    static let textPrimary = color(light: "372C24", dark: "F6ECE2")
    static let textSecondary = color(light: "8A7D73", dark: "CFBEAF")

    private static func color(light: String, dark: String) -> Color {
        Color.adaptive(lightHex: light, darkHex: dark)
    }
}
