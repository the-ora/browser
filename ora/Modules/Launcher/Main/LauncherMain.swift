import SwiftUI
enum MoveDirection {
    case up
    case down
}
class Debouncer {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func run(_ block: @escaping @Sendable () async -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem {
            Task { await block() }
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

let debouncer = Debouncer(delay: 0.3)

struct LauncherMain: View {
    struct Match {
        let text: String
        let color: Color
        let foregroundColor: Color
        let icon: String
        let originalAlias: String
        let searchURL: String
    }
    @Binding var text: String
    @Binding var match: Match?
    var isFocused: FocusState<Bool>.Binding
    let onTabPress: () -> Void
    let onSubmit: (String?) -> Void
    
    @Environment(\.theme) private var theme
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @State var focusedElement: UUID = UUID()
    
    @State private var suggestions: [LauncherSuggestion] = [
        
    ]
    func defaultSuggestions()-> [LauncherSuggestion]  {
        
        return [
            LauncherSuggestion(
                type: .suggestedQuery, title: "Search on Google",
                action: { onSubmit(nil) }),
            LauncherSuggestion(
                type: .aiChat,
                title: "Grok",
                name: "Grok",
                action: {
                    tabManager
                        .openFromEngine(
                            engineName:.grok,
                            query: text,
                            historyManager: historyManager
                        )
                }
            ),
            LauncherSuggestion(
                type: .aiChat,
                title: "ChatGPT",
                name: "ChatGPT",
                action: {
                    tabManager
                        .openFromEngine(
                            engineName:.chatgpt,
                            query: text,
                            historyManager: historyManager
                        )
                }
            )
            
        ]
    }
    private func isValidHostname(_ input: String) -> Bool {
        let regex = #"^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"#
        return input.range(of: regex, options: .regularExpression) != nil
    }
    func searchHandler(_ text: String){
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = defaultSuggestions()
            return
        }
        let histories = historyManager.search(text)
        let tabs = tabManager.search(text)
        suggestions = []
        var x  = 0
        for tab in tabs {
            
            if x >= 2 { break }
            suggestions.append(
                LauncherSuggestion(
                    type: .openedTab,
                    title: tab.title,
                    url: tab.url,
                    faviconURL: tab.favicon,
                    faviconLocalFile: tab.faviconLocalFile,
                    action: {
                        tabManager
                            .activateTab(tab)
                    }
                )
            )
            x += 1
            
        }
        
        // if input is url show open url option
        if let url = URL(string: text),
           url.scheme != nil || isValidHostname(text) {
            suggestions.append(LauncherSuggestion(
                type: .suggestedLink,
                title: text,
                url: url.scheme != nil ? url : URL(string: "https://\(text)")!,
                action: {
                    tabManager
                        .openTab(url: url.scheme != nil ? url : URL(string: "https://\(text)")!, historyManager: historyManager)
                }
            ))
        }
        // search on google
        suggestions.append(LauncherSuggestion(
            type: .suggestedQuery, title: "\(text) - Search with google",
            action: { onSubmit(nil) }))
        let at = suggestions.count
        
        debouncer.run {
            let searchEngine = SearchEngineService().getDefaultSearchEngine()
            if let autoSuggestions = searchEngine?.autoSuggestions {
                let searchSuggestions = await autoSuggestions(text)
                
                await MainActor.run {
                    var x = 0
                    for ss in searchSuggestions {
                        if x == 3 { break }
                        suggestions.insert(
                            LauncherSuggestion(
                                type: .suggestedQuery,
                                title: ss,
                                action: { onSubmit(ss) }
                            ),
                            at: at + x
                        )
                        x += 1
                    }
                }
            }
        }
        
        // show some history entries
        for history in histories {
            
            if x >= 5 { break }
            suggestions.append(
                LauncherSuggestion(
                    type: .suggestedLink,
                    title: history.title,
                    url: history.url,
                    faviconURL: history.faviconURL,
                    faviconLocalFile: history.faviconLocalFile,
                    action: {
                        tabManager
                            .openTab(
                                url:history.url,
                                historyManager: historyManager
                            )
                    }
                )
            )
            x += 1
            
        }
        if isAISuitableQuery(text) {
            // at the ai some ai suggestions
            suggestions.append( LauncherSuggestion(
                type: .aiChat,
                title: text,
                name: "Grok",
                action: {
                    tabManager
                        .openFromEngine(
                            engineName:.grok,
                            query: text,
                            historyManager: historyManager
                        )
                    }
                )
            )

            suggestions.append( LauncherSuggestion(
                type: .aiChat,
                title: text,
                name: "ChatGPT",
                action: {
                    tabManager
                        .openFromEngine(
                            engineName:.chatgpt,
                            query: text,
                            historyManager: historyManager
                        )
                    }
                )
            )
        }
        focusedElement = suggestions.first?.id ?? UUID()
        
    }
    func executeCommand(){
        if let suggestion = suggestions
            .first(where: {$0.id == focusedElement}) {
            suggestion.action()
            appState.showLauncher = false
        }
        
    }
    
    func moveFocusedElement(_ dir: MoveDirection) {
        guard let i = suggestions.firstIndex(where: { $0.id == focusedElement }) else { return }
        let offset = dir == .up ? -1 : 1
        let newIndex = (i + offset + suggestions.count) % suggestions.count
        focusedElement = suggestions[newIndex].id
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                if match == nil {
                    Image(systemName: getIconName(match: match, text: text))
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color(.placeholderTextColor))
                }
                
                if match != nil {
                    SearchEngineCapsule(
                        text: match?.text ?? "",
                        color: match?.color ?? .blue,
                        foregroundColor: match?.foregroundColor ?? .white,
                        icon: match?.icon ?? ""
                    )
                }
                LauncherTextField(
                    text: $text,
                    font: NSFont.systemFont(ofSize: 18, weight: .medium),
                    onTab: onTabPress,
                    onSubmit: {
                        executeCommand()
                    },
                    onDelete: {
                        if text.isEmpty && match != nil {
                            text = match!.originalAlias
                            match = nil
                            return true
                        }
                        return false
                    },
                    onMoveUp: {
                        moveFocusedElement(.up)
                    },
                    onMoveDown: {
                        moveFocusedElement(.down)
                    },
                    cursorColor: match?.color ?? (theme.foreground),
                    placeholder: getPlaceholder(match: match)
                )
                .onChange(of: text) { _,newText in
                    searchHandler(text)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .focused(isFocused)
            }
            .animation(nil, value: match?.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if match == nil, suggestions.count > 0 {
                LauncherSuggestionsView(
                    text: $text,
                    suggestions: $suggestions,
                    focusedElement: $focusedElement
                    
                )
            }
        }
        .padding(8)
        .frame(width: 814, alignment: .leading)
        .background(theme.launcherMainBackground)
        .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.25)
                .stroke(
                    Color(match?.color ?? theme.foreground).opacity(0.15),
                    lineWidth: 0.5)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 40, x: 0, y: 24
        )
    }
    
    private func getPlaceholder(match: Match?) -> String {
        if match == nil {
            return "Search the web or enter url..."
        }
        switch match!.text {
        case "X":
            return "Search on X"
        case "Youtube":
            return "Search on Youtube"
        case "Google":
            return "Search on Google"
        case "ChatGPT":
            return "Ask ChatGPT"
        case "Grok":
            return "Ask Grok"
        case "Perplexity":
            return "Ask Perplexity"
        case "Reddit":
            return "Search on Reddit"
        case "T3Chat":
            return "Ask T3Chat"
        default:
            return "Search on \(match!.text)"
        }
    }
    
    private func getIconName(match: Match?, text: String) -> String {
        if match != nil {
            return "magnifyingglass"
        }
        return isDomainOrIP(text) ? "globe" : "magnifyingglass"
    }
}

func isAISuitableQuery(_ query: String) -> Bool {
  let lowercased = query.lowercased()

  // AI-suited queries: open-ended, creative, opinion-based, etc.
  let aiKeywords = [
    #"^(who|when|where|what|how|why)\b.*\?$"#,  // e.g. "When was Apple founded?"
    #"^\d{4}"#,
    "summarize", "rewrite", "explain", "code", "how to", "generate",
    "idea", "opinion", "feedback", "story", "joke", "email", "draft",
    "translate", "compare", "alternatives", "improve", "fix", "suggest",
  ]

  for keyword in aiKeywords {
    if lowercased.contains(keyword) {
      return true
    }
  }

  return false
}
