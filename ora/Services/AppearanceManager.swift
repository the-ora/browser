import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    @AppStorage("ui.app.appearance") var appearance: AppAppearance = .system {
        didSet {
            updateAppearance()
        }
    }

    func updateAppearance() {
        guard NSApp != nil else {
            print("NSApp is nil, skipping appearance update")
            return
        }
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
