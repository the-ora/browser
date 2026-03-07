import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "SearchEngineService")

enum SearchEngineID: String, CaseIterable {
    case youtube = "YouTube"
    case chatgpt = "ChatGPT"
    case claude = "Claude"
    case google = "Google"
    case grok = "Grok"
    case perplexity = "Perplexity"
    case reddit = "Reddit"
    case t3chat = "T3Chat"
    // swiftlint:disable:next identifier_name
    case x = "X"
    case gemini = "Gemini"
    case copilot = "Copilot"
    case githubCopilot = "GitHub Copilot"
    case metaAI = "Meta AI"
}

struct SuggestResponse: Decodable {
    let query: String
    let suggestions: [String]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.query = try container.decode(String.self)
        self.suggestions = try container.decode([String].self)
        // Skip the rest (3rd and 4th elements)
    }
}

class SearchEngineService: ObservableObject {
    private var theme: Theme?
    @ObservedObject private var settingsStore = SettingsStore.shared

    func setTheme(_ theme: Theme) {
        self.theme = theme
    }

    var settings: SettingsStore {
        return settingsStore
    }

    /// All built-in search engine IDs derived from the built-in engines
    var builtInEngineIDs: [SearchEngineID] {
        return builtInSearchEngines.compactMap { SearchEngineID(rawValue: $0.name) }
    }

    /// Check if a name corresponds to a built-in search engine
    func isBuiltInEngine(_ name: String) -> Bool {
        return builtInSearchEngines.contains { $0.name == name }
    }

    /// Get SearchEngineID from engine name if it exists
    func getSearchEngineID(from name: String) -> SearchEngineID? {
        return SearchEngineID(rawValue: name)
    }

    var builtInSearchEngines: [SearchEngine] {
        [
            SearchEngine(
                name: "YouTube",
                color: Color(hex: "#FC0D1B"),
                icon: "",
                aliases: ["youtube", "you", "youtu", "yo", "yt"],
                searchURL: "https://www.youtube.com/results?search_query={query}",
                isAIChat: false
            ),
            SearchEngine(
                name: "ChatGPT",
                color: theme?.foreground ?? .white,
                icon: "openai-capsule-logo",
                aliases: ["chat", "chatgpt", "gpt", "cgpt", "openai", "cha"],
                searchURL: "https://chatgpt.com?q={query}",
                isAIChat: true,
                foregroundColor: theme?.background ?? .black
            ),
            SearchEngine(
                name: "Claude",
                color: Color(hex: "#DE7C4C"),
                icon: "",
                aliases: ["claude", "cl", "cla", "anthropic"],
                searchURL: "https://claude.ai?q={query}",
                isAIChat: true
            ),
            SearchEngine(
                name: "Google",
                color: .blue,
                icon: "",
                aliases: ["google", "goo", "g", "search"],
                searchURL:
                "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q={query}",
                isAIChat: false,
                autoSuggestions: self.googleSuggestions
            ),
            SearchEngine(
                name: "DuckDuckGo",
                color: Color(hex: "#DE5833"),
                icon: "",
                aliases: ["duckduckgo", "ddg", "duck"],
                searchURL: "https://duckduckgo.com/?q={query}",
                isAIChat: false
            ),
            SearchEngine(
                name: "Kagi",
                color: Color(hex: "#FFB319"),
                icon: "",
                aliases: ["kagi", "kg"],
                searchURL: "https://kagi.com/search?q={query}",
                isAIChat: false
            ),
            SearchEngine(
                name: "Bing",
                color: Color(hex: "#02B7E9"),
                icon: "",
                aliases: ["bing", "b", "microsoft"],
                searchURL: "https://www.bing.com/search?q={query}",
                isAIChat: false
            ),
            SearchEngine(
                name: "Grok",
                color: theme?.foreground ?? .white,
                icon: "grok-capsule-logo",
                aliases: ["grok", "gr", "gro"],
                searchURL: "https://grok.com?q={query}",
                isAIChat: true,
                foregroundColor: theme?.background ?? .black
            ),
            SearchEngine(
                name: "Perplexity",
                color: Color(hex: "#20808D"),
                icon: "perplexity-capsule-logo",
                aliases: ["perplexity", "perplex", "pplx", "ppl", "per"],
                searchURL: "https://www.perplexity.ai/search?q={query}",
                isAIChat: true
            ),
            SearchEngine(
                name: "Reddit",
                color: Color(hex: "#FF4500"),
                icon: "reddit-capsule-logo",
                aliases: ["reddit", "r", "rd", "rdit", "red"],
                searchURL: "https://www.reddit.com/search/?q={query}",
                isAIChat: false
            ),
            SearchEngine(
                name: "T3Chat",
                color: Color(hex: "#960971"),
                icon: "t3chat-capsule-logo",
                aliases: ["t3chat", "t3", "t3c", "tchat"],
                searchURL: "https://t3.chat/new?q={query}",
                isAIChat: true
            ),
            SearchEngine(
                name: "X",
                color: theme?.foreground ?? .white,
                icon: "",
                aliases: ["x", "x.com", "twitter", "tw", "twtr", "twit", "twitt", "twitte"],
                searchURL: "https://twitter.com/search?q={query}",
                isAIChat: false,
                foregroundColor: theme?.background ?? .black
            ),
            SearchEngine(
                name: "Gemini",
                color: Color(hex: "#4285F4"),
                icon: "",
                aliases: ["gemini", "gem", "bard", "google ai", "gai"],
                searchURL: "https://gemini.google.com/app?q={query}",
                isAIChat: true
            ),
            SearchEngine(
                name: "Copilot",
                color: Color(hex: "#0078D4"),
                icon: "",
                aliases: ["copilot", "microsoft copilot", "bing chat", "bing", "ms copilot"],
                searchURL: "https://copilot.microsoft.com/?q={query}",
                isAIChat: true
            ),
            SearchEngine(
                name: "GitHub Copilot",
                color: Color(hex: "#24292F"),
                icon: "",
                aliases: ["github copilot", "gh copilot", "github ai", "ghc"],
                searchURL: "https://github.com/copilot?q={query}",
                isAIChat: true,
                foregroundColor: .white
            ),
            SearchEngine(
                name: "Meta AI",
                color: Color(hex: "#0866FF"),
                icon: "",
                aliases: ["meta ai", "meta", "llama", "facebook ai", "mai"],
                searchURL: "https://www.meta.ai/?q={query}",
                isAIChat: true
            )
        ]
    }

    var searchEngines: [SearchEngine] {
        var engines = builtInSearchEngines

        let customEngines = settingsStore.customSearchEngines.map { custom in
            SearchEngine(
                name: custom.name,
                color: custom.faviconBackgroundColor ?? .blue,
                icon: "",
                aliases: custom.aliases,
                searchURL: custom.searchURL,
                isAIChat: custom.isAIChat
            )
        }

        engines.append(contentsOf: customEngines)
        return engines
    }

    func findSearchEngine(for alias: String) -> SearchEngine? {
        let textLowercased = alias.lowercased()
        return searchEngines.first(where: { $0.aliases.contains(textLowercased) })
    }

    func getDefaultSearchEngine(for containerId: UUID? = nil) -> SearchEngine? {
        // First check per-container setting
        if let containerId,
           let defaultId = settingsStore.defaultSearchEngineId(for: containerId),
           let engine = searchEngines.first(where: { $0.name == defaultId })
        {
            return engine
        }

        // Then check global default setting
        if let globalDefaultId = settingsStore.globalDefaultSearchEngine,
           let engine = searchEngines.first(where: { $0.name == globalDefaultId })
        {
            return engine
        }

        // Fallback to Google if no custom default is set
        return searchEngines.first(where: { $0.name == "Google" })
    }

    func getDefaultAIChat(for containerId: UUID? = nil) -> SearchEngine? {
        if let containerId,
           let defaultId = settingsStore.defaultAIEngineId(for: containerId),
           let engine = searchEngines.first(where: { $0.name == defaultId && $0.isAIChat })
        {
            return engine
        }

        // Fallback to ChatGPT if no custom default is set
        return searchEngines.first(where: { $0.isAIChat && $0.name == "ChatGPT" })
    }

    func getSearchEngine(_ engineName: SearchEngineID) -> SearchEngine? {
        return searchEngines.first(where: { $0.name == engineName.rawValue })
    }

    func getSearchEngine(byName name: String) -> SearchEngine? {
        return searchEngines.first(where: { $0.name == name })
    }

    func getSearchURLForEngine(engineName: SearchEngineID, query: String) -> URL? {
        if let engine = getSearchEngine(engineName) {
            if let url = createSearchURL(
                for: engine,
                query: query
            ) {
                return url
            }
        }
        return nil
    }

    func createSearchURL(for engine: SearchEngine, query: String) -> URL? {
        let encodedQuery =
            query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = engine.searchURL.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func createSearchURL(for match: LauncherMain.Match, query: String) -> URL? {
        let encodedQuery =
            query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = match.searchURL.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func createSuggestionsURL(urlString: String, query: String) -> URL? {
        let encodedQuery =
            query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = urlString.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func googleSuggestions(_ query: String) async -> [String] {
        guard
            let url = createSuggestionsURL(
                urlString:
                "https://suggestqueries.google.com/complete/search?client=firefox&q={query}",
                query: query
            )
        else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SuggestResponse.self, from: data)
            return decoded.suggestions
        } catch {
            logger.error("Error fetching Google suggestions: \(error.localizedDescription)")
            return []
        }
    }
}
