import SwiftUI

enum SearchEngineID: String, CaseIterable {
    case google = "Google"
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

    var builtInSearchEngines: [SearchEngine] {
        [
            SearchEngine(
                name: "Google",
                color: .blue,
                icon: "",
                aliases: ["google", "goo", "g", "search"],
                searchURL: "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q={query}",
                isAIChat: false,
                autoSuggestions: self.googleSuggestions
            )
        ]
    }

    var searchEngines: [SearchEngine] {
        var engines = builtInSearchEngines

        let customEngines = settingsStore.customSearchEngines.map { custom in
            SearchEngine(
                name: custom.name,
                color: .blue,
                icon: "",
                aliases: custom.aliases,
                searchURL: custom.searchURL,
                isAIChat: false
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
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = engine.searchURL.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func createSearchURL(for match: LauncherMain.Match, query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = match.searchURL.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func createSuggestionsURL(urlString: String, query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = urlString.replacingOccurrences(of: "{query}", with: encodedQuery)
        return URL(string: urlString)
    }

    func googleSuggestions(_ query: String) async -> [String] {
        guard let url = createSuggestionsURL(
            urlString: "https://suggestqueries.google.com/complete/search?client=firefox&q={query}",
            query: query
        ) else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SuggestResponse.self, from: data)
            return decoded.suggestions
        } catch {
            print("Error: \(error)")
            return []
        }
    }
}
