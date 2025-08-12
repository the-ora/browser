import SwiftUI

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

    init() {
        let saved = UserDefaults.standard.string(forKey: "AppAppearance")
        self.appearance = AppAppearance(rawValue: saved ?? "") ?? .system
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
