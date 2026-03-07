import SwiftUI

enum SettingsTab: String, Hashable {
    case general
    case spaces
    case privacySecurity
    case passwords
    case shortcuts
    case searchEngines

    var title: String {
        switch self {
        case .general: return "General"
        case .spaces: return "Spaces"
        case .privacySecurity: return "Privacy"
        case .passwords: return "Passwords"
        case .shortcuts: return "Shortcuts"
        case .searchEngines: return "Search"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .spaces: return "rectangle.3.group"
        case .privacySecurity: return "lock.shield"
        case .passwords: return "key.horizontal"
        case .shortcuts: return "command"
        case .searchEngines: return "magnifyingglass"
        }
    }
}

struct SettingsContentView: View {
    static let selectedTabDefaultsKey = "settings.selectedTab"

    @AppStorage(Self.selectedTabDefaultsKey) private var selectionRawValue: String = SettingsTab.general.rawValue

    private var selection: Binding<SettingsTab> {
        Binding(
            get: { SettingsTab(rawValue: selectionRawValue) ?? .general },
            set: { selectionRawValue = $0.rawValue }
        )
    }

    var body: some View {
        TabView(selection: selection) {
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

            PasswordsSettingsView()
                .tabItem { Label(SettingsTab.passwords.title, systemImage: SettingsTab.passwords.symbol) }
                .tag(SettingsTab.passwords)

            ShortcutsSettingsView()
                .tabItem { Label(SettingsTab.shortcuts.title, systemImage: SettingsTab.shortcuts.symbol) }
                .tag(SettingsTab.shortcuts)

            SearchEngineSettingsView()
                .tabItem { Label(SettingsTab.searchEngines.title, systemImage: SettingsTab.searchEngines.symbol) }
                .tag(SettingsTab.searchEngines)
        }
        .tabViewStyle(.automatic)
        .frame(width: 860, height: 600)
        .padding(0)
        .controlSize(.regular)
    }
}
