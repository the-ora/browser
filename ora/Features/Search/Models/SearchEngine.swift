import SwiftUI

struct SearchEngine {
    let name: String
    let color: Color
    let icon: String
    let aliases: [String]
    let searchURL: String
    let isAIChat: Bool
    let foregroundColor: Color?
    let autoSuggestions: ((String) async -> [String])?

    init(
        name: String,
        color: Color,
        icon: String,
        aliases: [String],
        searchURL: String,
        isAIChat: Bool,
        foregroundColor: Color? = nil,
        autoSuggestions: ((String) async -> [String])? = nil
    ) {
        self.name = name
        self.color = color
        self.icon = icon
        self.aliases = aliases
        self.searchURL = searchURL
        self.isAIChat = isAIChat
        self.foregroundColor = foregroundColor
        self.autoSuggestions = autoSuggestions
    }
}

extension SearchEngine {
    func toLauncherMatch(
        originalAlias: String,
        customEngine: CustomSearchEngine? = nil
    ) -> LauncherMain.Match {
        var favicon: NSImage?
        var faviconColor: Color?

        // Use cached favicon data from custom engine if available
        if let customEngine {
            favicon = customEngine.favicon
            faviconColor = customEngine.faviconBackgroundColor
        } else {
            // For built-in engines, use favicon service
            favicon = FaviconService.shared.getFavicon(for: searchURL)
            faviconColor = FaviconService.shared.getFaviconColor(for: searchURL)
        }

        return LauncherMain.Match(
            text: name,
            color: color,
            foregroundColor: foregroundColor ?? .white,
            icon: icon,
            originalAlias: originalAlias,
            searchURL: searchURL,
            favicon: favicon,
            faviconBackgroundColor: faviconColor
        )
    }
}
