import SwiftUI

struct SearchEngine {
    let name: String
    let color: Color
    let icon: String
    let aliases: [String]
    let searchURL: String
    let isAIChat: Bool
    let isLocal: Bool
    let foregroundColor: Color?
    let autoSuggestions: ((String) async -> [String])?

    init(
        name: String,
        color: Color,
        icon: String,
        aliases: [String],
        searchURL: String,
        isAIChat: Bool,
        isLocal: Bool = false,
        foregroundColor: Color? = nil,
        autoSuggestions: ((String) async -> [String])? = nil
    ) {
        self.name = name
        self.color = color
        self.icon = icon
        self.aliases = aliases
        self.searchURL = searchURL
        self.isAIChat = isAIChat
        self.isLocal = isLocal
        self.foregroundColor = foregroundColor
        self.autoSuggestions = autoSuggestions
    }
}

extension SearchEngine {
    func toLauncherMatch(originalAlias: String) -> LauncherMain.Match {
        return LauncherMain.Match(
            text: name,
            color: color,
            foregroundColor: foregroundColor ?? .white,
            icon: icon,
            originalAlias: originalAlias,
            searchURL: searchURL
        )
    }
}
