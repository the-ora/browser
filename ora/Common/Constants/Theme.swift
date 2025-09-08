import AppKit
import SwiftUI

extension Notification.Name {
    static let colorThemeChanged = Notification.Name("colorThemeChanged")
    static let customColorChanged = Notification.Name("customColorChanged")
}

struct ThemeConstants {
    static let colorTransitionDuration: Double = 0.3
    static let colorThemeUserDefaultsKey = "ColorTheme"
    static let customColorLightKey = "CustomColorLight"
    static let customColorDarkKey = "CustomColorDark"
}

enum ColorTheme: String, CaseIterable, Identifiable {
    case orange = "Orange"
    case blue = "Blue"
    case green = "Green"
    case purple = "Purple"
    case red = "Red"
    case teal = "Teal"
    case gray = "Gray"
    case custom = "Custom"

    var id: String { rawValue }

    var primaryLight: Color {
        switch self {
        case .orange: return Color(hex: "f3e5d6")
        case .blue: return Color(hex: "d6e5f3")
        case .green: return Color(hex: "d6f3e5")
        case .purple: return Color(hex: "e5d6f3")
        case .red: return Color(hex: "f3d6d6")
        case .teal: return Color(hex: "d6f3f0")
        case .gray: return Color(hex: "e5e5e5")
        case .custom:
            // Load custom color from UserDefaults and soften it for light mode
            if let hexString = UserDefaults.standard.string(forKey: ThemeConstants.customColorLightKey) {
                let originalColor = Color(hex: hexString)
                // Soften the color: increase brightness, reduce saturation
                return originalColor.adjusted(brightness: 1.3, saturation: 0.6)
            }
            return Color(hex: "f3e5d6") // fallback to orange
        }
    }

    var primaryDark: Color {
        switch self {
        case .orange: return Color(hex: "63411D")
        case .blue: return Color(hex: "1D4163")
        case .green: return Color(hex: "1D6341")
        case .purple: return Color(hex: "411D63")
        case .red: return Color(hex: "631D1D")
        case .teal: return Color(hex: "1D6360")
        case .gray: return Color(hex: "414141")
        case .custom:
            // Load custom color from UserDefaults
            if let hexString = UserDefaults.standard.string(forKey: ThemeConstants.customColorDarkKey) {
                return Color(hex: hexString)
            }
            return Color(hex: "63411D") // fallback to orange
        }
    }
}

// swiftlint:disable:next identifier_name
struct Theme: Equatable {
    let colorScheme: ColorScheme
    let colorTheme: ColorTheme
    let updateTrigger: Int

    var primary: Color {
        colorTheme.primaryLight
    }

    var primaryDark: Color {
        colorTheme.primaryDark
    }

    var accent: Color {
        if colorTheme == .custom {
            // Use a subtle version of the custom color as accent
            let customColor = colorTheme.primaryLight
            return customColor.adjusted(brightness: 1.1, saturation: 0.9)
        }
        return Color(hex: "FF5F57")
    }

    var background: Color {
        colorScheme == .dark ? Color(hex: "#141414") : .white
    }

    var foreground: Color {
        colorScheme == .dark ? .white : .black
    }

    var subtleWindowBackgroundColor: Color {
        colorScheme == .dark ? self.primaryDark.opacity(0.3) : self.primary.opacity(0.8)
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
    static let defaultValue = Theme(colorScheme: .light, colorTheme: .orange, updateTrigger: 0)  // fallback
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeProvider: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var colorTheme: ColorTheme = {
        // Load initial value synchronously
        let saved = UserDefaults.standard.string(forKey: ThemeConstants.colorThemeUserDefaultsKey)
        return ColorTheme(rawValue: saved ?? "") ?? .orange
    }()
    @State private var customColorUpdateTrigger = 0

    func body(content: Content) -> some View {
        content
            .environment(\.theme, Theme(colorScheme: colorScheme, colorTheme: colorTheme, updateTrigger: customColorUpdateTrigger))
            .onReceive(NotificationCenter.default.publisher(for: .colorThemeChanged)) { notification in
                if let newTheme = notification.object as? ColorTheme {
                    withAnimation(.easeInOut(duration: ThemeConstants.colorTransitionDuration)) {
                        colorTheme = newTheme
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .customColorChanged)) { _ in
                // Trigger theme update when custom colors change
                if colorTheme == .custom {
                    withAnimation(.easeInOut(duration: ThemeConstants.colorTransitionDuration)) {
                        customColorUpdateTrigger += 1
                    }
                }
            }
    }
}
