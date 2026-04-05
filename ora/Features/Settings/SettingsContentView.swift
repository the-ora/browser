import AppKit
import SwiftUI

enum SettingsTab: String, Hashable, CaseIterable {
    case general
    case spaces
    case passwords
    case shortcuts
    case searchEngines

    var title: String {
        switch self {
        case .general: return "General"
        case .spaces: return "Spaces"
        case .passwords: return "Passwords"
        case .shortcuts: return "Shortcuts"
        case .searchEngines: return "Search"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .spaces: return "rectangle.3.group"
        case .passwords: return "key.horizontal"
        case .shortcuts: return "command"
        case .searchEngines: return "magnifyingglass"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Browser defaults, app behavior, and software updates."
        case .spaces:
            return "Space-specific defaults and per-space data controls."
        case .passwords:
            return "Password manager integration, vault access, and autofill behavior."
        case .shortcuts:
            return "Keyboard shortcuts and command mappings."
        case .searchEngines:
            return "Default search providers, AI engines, and custom shortcuts."
        }
    }
}

struct SettingsWindowRoot: View {
    var body: some View {
        SettingsContentView()
            .environmentObject(ToastManager.shared)
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

    private var selectedTab: SettingsTab {
        SettingsTab(rawValue: selectionRawValue) ?? .general
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: selection) { tab in
                Label(tab.title, systemImage: tab.symbol)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(200)
            .padding(.top, 8)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(selectedTab.title)
                .navigationSubtitle(selectedTab.subtitle)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .spaces:
            SpacesSettingsView()
        case .passwords:
            PasswordsSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .searchEngines:
            SearchEngineSettingsView()
        }
    }
}
