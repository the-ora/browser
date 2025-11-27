import AppKit
import SwiftUI

// swiftlint:disable identifier_name
struct Theme: Equatable {
    let colorScheme: ColorScheme
    let customPrimaryColor: String?
    let customAccentColor: String?

    init(colorScheme: ColorScheme, customPrimaryColor: String? = nil, customAccentColor: String? = nil) {
        self.colorScheme = colorScheme
        self.customPrimaryColor = customPrimaryColor
        self.customAccentColor = customAccentColor
    }

    var primary: Color {
        if let hex = customPrimaryColor {
            return Color(hex: hex)
        }
        return Color(hex: "#d6f3ea")
    }

    var primaryDark: Color {
        // Use the same color as primary for both light and dark modes
        return primary
    }

    var accent: Color {
        if let hex = customAccentColor {
            return Color(hex: hex)
        }
        return Color(hex: "#575dff")
    }

    var background: Color {
        colorScheme == .dark ? Color(hex: "#0F0E0E") : .white
    }

    var foreground: Color {
        colorScheme == .dark ? .white : .black
    }

    var subtleWindowBackgroundColor: Color {
        colorScheme == .dark ? self.primaryDark.opacity(0.3) : self.primary.opacity(0.3)
    }

    var solidWindowBackgroundColor: Color {
        colorScheme == .dark ? self.primaryDark : self.primary
    }

    var invertedSolidWindowBackgroundColor: Color {
        colorScheme == .dark ? self.primary : self.primaryDark
    }

    var activeTabBackground: Color {
        colorScheme == .dark ? .white.opacity(0.15) : self.primaryDark.opacity(0.8)
    }

    var mutedBackground: Color {
        colorScheme == .dark ? .white.opacity(0.17) : self.primaryDark.opacity(0.1)
    }

    var mutedForeground: Color {
        .secondary
    }

    var disabledBackground: Color {
        colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.3)
    }

    var disabledForeground: Color {
        colorScheme == .dark ? .white.opacity(0.3) : Color(.disabledControlTextColor)
    }

    var launcherMainBackground: Color {
        colorScheme == .dark ? Color(.windowBackgroundColor).opacity(0.7) : .white.opacity(0.8)
    }

    var placeholder: Color {
        Color(.placeholderTextColor)
    }

    var border: Color {
        Color(.separatorColor)
    }

    var destructive: Color {
        Color(hex: "#FF6969")
    }

    var success: Color {
        Color(hex: "#93DA97")
    }

    var warning: Color {
        Color(hex: "#FFBF78")
    }

    var info: Color {
        Color(hex: "#799EFF")
    }

    // Search engine colors
    var grok: Color {
        colorScheme == .dark ? .white : .black
    }

    var claude: Color {
        Color(hex: "#d97757")
    }

    var openai: Color {
        colorScheme == .dark ? .white : .black
    }

    var t3chat: Color {
        Color(hex: "#960971")
    }

    var perplexity: Color {
        Color(hex: "#20808D")
    }

    var reddit: Color {
        Color(hex: "#FF4500")
    }

    var x: Color {
        colorScheme == .dark ? .white : .black
    }

    var google: Color {
        .blue
    }

    var youtube: Color {
        Color(hex: "#FC0D1B")
    }

    var github: Color {
        colorScheme == .dark ? .white : Color(hex: "#181717")
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(colorScheme: .light)  // fallback
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeProvider: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        content.environment(
            \.theme,
            Theme(
                colorScheme: colorScheme,
                customPrimaryColor: settings.themePrimaryColor,
                customAccentColor: settings.themeAccentColor
            )
        )
    }
}
