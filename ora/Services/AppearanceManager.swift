import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

@Observable @MainActor
final class AppearanceManager {
    var appearance: AppAppearance {
        didSet {
            updateAppearance()
            UserDefaults.standard.set(appearance.rawValue, forKey: "AppAppearance")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "AppAppearance")
        self.appearance = AppAppearance(rawValue: saved ?? "") ?? .system
        updateAppearance()
    }

    func updateAppearance() {
        switch appearance {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
