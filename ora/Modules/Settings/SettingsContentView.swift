import SwiftUI

enum SettingsTab: Hashable, CaseIterable {
    case general, spaces, privacySecurity, shortcuts, searchEngines

    var title: String {
        switch self {
        case .general: return "General"
        case .spaces: return "Spaces"
        case .privacySecurity: return "Privacy"
        case .shortcuts: return "Shortcuts"
        case .searchEngines: return "Search"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .spaces: return "rectangle.3.group"
        case .privacySecurity: return "lock.shield"
        case .shortcuts: return "command"
        case .searchEngines: return "magnifyingglass"
        }
    }
}

struct SettingsContentView: View {
    @State private var selection: SettingsTab = .general
    @Environment(\.theme) private var theme: Theme

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.symbol)
                            Text(tab.title)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 35, maxHeight: 35, alignment: .leading)
                    .background(selection == tab ? theme.mutedSidebarBackground : .clear)
                    .cornerRadius(10)
                    .overlay(
                        ConditionallyConcentricRectangle(cornerRadius: 10)
                            .stroke(selection == tab ? theme.border : .clear, lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 8)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selection {
                case .general:
                    GeneralSettingsView()
                case .spaces:
                    SpacesSettingsView()
                case .privacySecurity:
                    PrivacySecuritySettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .searchEngines:
                    SearchEngineSettingsView()
                }
            }
            .toolbar {
                ToolbarItem(content: {
                    HStack { Text(selection.title).font(.title3) }.padding(.horizontal, 12)
                })
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(theme.background)
        .navigationSplitViewStyle(.balanced)
    }
}
