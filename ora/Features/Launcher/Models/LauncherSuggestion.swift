import SwiftUI

enum LauncherSuggestionType {
    case openedTab, suggestedQuery, suggestedLink, aiChat
}

struct LauncherSuggestion: Identifiable {
    let id = UUID()
    let type: LauncherSuggestionType
    let title: String
    let name: String?
    let url: URL?
    let icon: String?
    let color: Color?
    let engineForegroundColor: Color?
    let faviconURL: URL?
    let faviconLocalFile: URL?
    let action: () -> Void

    init(
        type: LauncherSuggestionType,
        title: String,
        name: String? = nil,
        url: URL? = nil,
        icon: String? = nil,
        color: Color? = nil,
        engineForegroundColor: Color? = nil,
        faviconURL: URL? = nil,
        faviconLocalFile: URL? = nil,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.title = title
        self.name = name
        self.url = url
        self.icon = icon
        self.color = color
        self.engineForegroundColor = engineForegroundColor
        self.faviconURL = faviconURL
        self.faviconLocalFile = faviconLocalFile
        self.action = action
    }
}
