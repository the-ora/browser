import SwiftUI
import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

class AppearanceManager: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet {
            updateAppearance()
            UserDefaults.standard.set(appearance.rawValue, forKey: "AppAppearance")
        }
    }
    
    @Published var colorTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(colorTheme.rawValue, forKey: ThemeConstants.colorThemeUserDefaultsKey)
            NotificationCenter.default.post(name: .colorThemeChanged, object: colorTheme)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "AppAppearance")
        self.appearance = AppAppearance(rawValue: saved ?? "") ?? .system
        
        let savedColorTheme = UserDefaults.standard.string(forKey: ThemeConstants.colorThemeUserDefaultsKey)
        self.colorTheme = ColorTheme(rawValue: savedColorTheme ?? "") ?? .orange
        
        updateAppearance()
    }

    func updateAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
