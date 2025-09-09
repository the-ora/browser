import SwiftUI

extension Color {
    // swiftlint:disable identifier_name
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    // swiftlint:enable identifier_name

    /// Converts the Color to a hex string in `#RRGGBB` or `#RRGGBBAA` format
    func toHex(includeAlpha: Bool = false) -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return nil
        }
        // swiftlint:disable identifier_name
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        let a = Int(rgbColor.alphaComponent * 255)
        // swiftlint:enable identifier_name

        return includeAlpha
            ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
            : String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Adjusts the brightness and saturation of a color
    func adjusted(brightness: Double = 1.0, saturation: Double = 1.0) -> Color {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return self
        }
        // swiftlint:disable identifier_name
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // swiftlint:enable identifier_name
        rgbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return Color(
            hue: Double(h),
            saturation: min(1.0, Double(s) * saturation),
            brightness: min(1.0, Double(b) * brightness)
        ).opacity(Double(a))
    }

    /// Calculates the relative luminance of a color using the WCAG formula
    var luminance: Double {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return 0.5 // fallback to medium luminance
        }

        // Convert to linear RGB
        func linearize(_ component: Double) -> Double {
            if component <= 0.03928 {
                return component / 12.92
            } else {
                return pow((component + 0.055) / 1.055, 2.4)
            }
        }
        // swiftlint:disable identifier_name
        let r = linearize(rgbColor.redComponent)
        let g = linearize(rgbColor.greenComponent)
        let b = linearize(rgbColor.blueComponent)
        // swiftlint:enable identifier_name

        // WCAG luminance formula
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Returns an appropriate foreground color (black or white) based on the background's luminance
    var adaptiveForeground: Color {
        return luminance > 0.5 ? .black : .white
    }

    /// Returns a contrasting foreground color with optional opacity
    func contrastingForeground(opacity: Double = 1.0) -> Color {
        return adaptiveForeground.opacity(opacity)
    }
}
