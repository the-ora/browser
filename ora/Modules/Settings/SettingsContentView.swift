import SwiftUI

enum SettingsTab: Hashable {
    case general, spaces, privacySecurity, shortcuts

    var title: String {
        switch self {
        case .general: return "General"
        case .spaces: return "Spaces"
        case .privacySecurity: return "Privacy"
        case .shortcuts: return "Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .spaces: return "rectangle.3.group"
        case .privacySecurity: return "lock.shield"
        case .shortcuts: return "command"
        }
    }
}

struct SettingsContentView: View {
    @State private var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.symbol) }
                .tag(SettingsTab.general)

            SpacesSettingsView()
                .tabItem { Label(SettingsTab.spaces.title, systemImage: SettingsTab.spaces.symbol) }
                .tag(SettingsTab.spaces)

            PrivacySecuritySettingsView()
                .tabItem {
                    Label(SettingsTab.privacySecurity.title, systemImage: SettingsTab.privacySecurity.symbol)
                }
                .tag(SettingsTab.privacySecurity)

            ShortcutsSettingsView()
                .tabItem { Label(SettingsTab.shortcuts.title, systemImage: SettingsTab.shortcuts.symbol) }
                .tag(SettingsTab.shortcuts)
        }
        .tabViewStyle(.automatic)
        .frame(width: 600, height: 350)
        .padding(0)
        .controlSize(.regular)
    }
}
