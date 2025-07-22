import SwiftUI
enum SearchEngineID: String, CaseIterable {
    case youtube = "YouTube"
    case chatgpt = "ChatGPT"
    case google = "Google"
    case grok = "Grok"
    case perplexity = "Perplexity"
    case reddit = "Reddit"
    case t3chat = "T3Chat"
    case x = "X"
}
class SearchEngineService: ObservableObject {
    private var theme: Theme?
    
    func setTheme(_ theme: Theme) {
        self.theme = theme
    }
    
    var searchEngines: [SearchEngine] {
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
                name: "Google",
                color: .blue,
                icon: "",
                aliases: ["google", "goo", "g", "search"],
                searchURL: "https://www.google.com/search?q={query}",
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
        ]
    }
    
    func findSearchEngine(for alias: String) -> SearchEngine? {
        let textLowercased = alias.lowercased()
        return searchEngines.first(where: { $0.aliases.contains(textLowercased) })
    }
    
    func getDefaultSearchEngine() -> SearchEngine? {
        return searchEngines.first(where: { $0.name == "Google" })
    }
    
    func getDefaultAIChat() -> SearchEngine? {
        return searchEngines.first(where: { $0.isAIChat && $0.name == "ChatGPT" })
    }
    
    func getSearchEngine(_ engineName: SearchEngineID) -> SearchEngine? {
        return searchEngines.first(where: { $0.name == engineName.rawValue })
    }
    
    func getSearchURLForEngine(engineName: SearchEngineID,query: String) -> URL? {
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
    
}
