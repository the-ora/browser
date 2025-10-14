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

let debouncer = Debouncer(delay: 0.2)

struct LauncherMain: View {
    struct Match {
        let text: String
        let color: Color
        let foregroundColor: Color
        let icon: String
        let originalAlias: String
        let searchURL: String
        let favicon: NSImage?
        let faviconBackgroundColor: Color?
    }

    @Binding var text: String
    @Binding var match: Match?
    var isFocused: FocusState<Bool>.Binding
    let onTabPress: () -> Void
    let onSubmit: (String?) -> Void

    @Environment(\.theme) private var theme
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var privacyMode: PrivacyMode
    @State var focusedElement: UUID = .init()

    @StateObject private var searchEngineService = SearchEngineService()

    @State private var suggestions: [LauncherSuggestion] = []

    private func createAISuggestion(engineName: SearchEngineID, query: String? = nil)
        -> LauncherSuggestion
    {
        guard let engine = searchEngineService.getSearchEngine(engineName) else {
            return LauncherSuggestion(
                type: .aiChat,
                title: query ?? engineName.rawValue,
                name: engineName.rawValue,
                action: {}
            )
        }

        _ = FaviconService.shared.getFavicon(for: engine.searchURL)
        let faviconURL = FaviconService.shared.faviconURL(for: URL(string: engine.searchURL)?.host ?? "")

        return LauncherSuggestion(
            type: .aiChat,
            title: query ?? engine.name,
            name: engine.name,
            faviconURL: faviconURL,
            action: {
                tabManager.openFromEngine(
                    engineName: engineName,
                    query: query ?? text,
                    historyManager: historyManager,
                    isPrivate: privacyMode.isPrivate
                )
            }
        )
    }

    func defaultSuggestions() -> [LauncherSuggestion] {
        let containerId = tabManager.activeContainer?.id
        let searchEngine = searchEngineService.getDefaultSearchEngine(for: containerId)
        let engineName = searchEngine?.name ?? "Google"
        return [
            LauncherSuggestion(
                type: .suggestedQuery, title: "Search on \(engineName)",
                action: { onSubmit(nil) }
            ),
            createAISuggestion(engineName: .grok),
            createAISuggestion(engineName: .chatgpt),
            createAISuggestion(engineName: .claude),
            createAISuggestion(engineName: .gemini)
        ]
    }

    private func isValidHostname(_ input: String) -> Bool {
        let regex = #"^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"#
        return input.range(of: regex, options: .regularExpression) != nil
    }

    func searchHandler(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = defaultSuggestions()
            return
        }

        let histories = historyManager.search(
            text,
            activeContainerId: tabManager.activeContainer?.id ?? UUID()
        )
        let tabs = tabManager.search(text)

        suggestions = []

        var itemsCount = 0
        appendOpenTabs(tabs, itemsCount: &itemsCount)
        appendOpenURLSuggestionIfNeeded(text)
        appendSearchWithDefaultEngineSuggestion(text)

        let insertIndex = suggestions.count
        requestAutoSuggestions(text, insertAt: insertIndex)

        appendHistorySuggestions(histories, itemsCount: &itemsCount)
        appendAISuggestionsIfNeeded(text)

        focusedElement = suggestions.first?.id ?? UUID()
    }

    private func appendOpenTabs(_ tabs: [Tab], itemsCount: inout Int) {
        for tab in tabs {
            if itemsCount >= 2 { break }
            suggestions.append(
                LauncherSuggestion(
                    type: .openedTab,
                    title: tab.title,
                    url: tab.url,
                    faviconURL: tab.favicon,
                    faviconLocalFile: tab.faviconLocalFile,
                    action: {
                        if !tab.isWebViewReady {
                            tab.restoreTransientState(
                                historyManager: historyManager,
                                downloadManager: downloadManager,
                                tabManager: tabManager,
                                isPrivate: privacyMode.isPrivate
                            )
                        }
                        tabManager.activateTab(tab)
                    }
                )
            )
            itemsCount += 1
        }
    }

    private func appendOpenURLSuggestionIfNeeded(_ text: String) {
        guard let candidateURL = URL(string: text) else { return }
        let finalURL: URL? =
            if candidateURL.scheme != nil {
                candidateURL
            } else if isValidURL(text) {
                constructURL(from: text)
            } else {
                nil
            }
        guard let url = finalURL else { return }
        suggestions.append(
            LauncherSuggestion(
                type: .suggestedLink,
                title: text,
                url: url,
                action: {
                    tabManager.openTab(
                        url: url,
                        historyManager: historyManager,
                        downloadManager: downloadManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            )
        )
    }

    private func appendSearchWithDefaultEngineSuggestion(_ text: String) {
        let containerId = tabManager.activeContainer?.id
        let searchEngine = searchEngineService.getDefaultSearchEngine(for: containerId)
        let engineName = searchEngine?.name ?? "Google"
        suggestions.append(
            LauncherSuggestion(
                type: .suggestedQuery,
                title: "\(text) - Search with \(engineName)",
                action: { onSubmit(nil) }
            )
        )
    }

    private func requestAutoSuggestions(_ text: String, insertAt: Int) {
        let containerId = tabManager.activeContainer?.id
        debouncer.run {
            let searchEngine = self.searchEngineService.getDefaultSearchEngine(for: containerId)
            if let autoSuggestions = searchEngine?.autoSuggestions {
                let searchSuggestions = await autoSuggestions(text)
                await MainActor.run {
                    var localCount = 0
                    for ss in searchSuggestions {
                        if localCount == 3 { break }
                        let insertIndex = insertAt + localCount
                        let suggestion = LauncherSuggestion(
                            type: .suggestedQuery,
                            title: ss,
                            action: { onSubmit(ss) }
                        )
                        if insertIndex <= suggestions.count {
                            suggestions.insert(suggestion, at: insertIndex)
                        } else {
                            suggestions.append(suggestion)
                        }
                        localCount += 1
                    }
                }
            }
        }
    }

    private func appendHistorySuggestions(_ histories: [History], itemsCount: inout Int) {
        for history in histories {
            if itemsCount >= 5 { break }
            suggestions.append(
                LauncherSuggestion(
                    type: .suggestedLink,
                    title: history.title,
                    url: history.url,
                    faviconURL: history.faviconURL,
                    faviconLocalFile: history.faviconLocalFile,
                    action: {
                        tabManager.openTab(
                            url: history.url,
                            historyManager: historyManager,
                            isPrivate: privacyMode.isPrivate
                        )
                    }
                )
            )
            itemsCount += 1
        }
    }

    private func appendAISuggestionsIfNeeded(_ text: String) {
        guard isAISuitableQuery(text) else { return }
        suggestions.append(createAISuggestion(engineName: .grok, query: text))
        suggestions.append(createAISuggestion(engineName: .chatgpt, query: text))
        suggestions.append(createAISuggestion(engineName: .claude, query: text))
        suggestions.append(createAISuggestion(engineName: .gemini, query: text))
    }

    func executeCommand() {
        if let suggestion =
            suggestions
                .first(where: { $0.id == focusedElement })
        {
            suggestion.action()
            appState.showLauncher = false
        }
    }

    func moveFocusedElement(_ dir: MoveDirection) {
        guard let idx = suggestions.firstIndex(where: { $0.id == focusedElement }) else { return }
        let offset = dir == .up ? -1 : 1
        let newIndex = (idx + offset + suggestions.count) % suggestions.count
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
                        icon: match?.icon ?? "",
                        favicon: match?.favicon,
                        faviconBackgroundColor: match?.faviconBackgroundColor
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
                        if text.isEmpty, match != nil {
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
                    cursorColor: match?.faviconBackgroundColor ?? match?.color
                        ?? (theme.foreground),
                    placeholder: getPlaceholder(match: match)
                )
                .onChange(of: text) { _, _ in
                    searchHandler(text)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .focused(isFocused)
            }
            .animation(nil, value: match?.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            if match == nil, !suggestions.isEmpty {
                LauncherSuggestionsView(
                    text: $text,
                    suggestions: $suggestions,
                    focusedElement: $focusedElement
                )
            }
        }
        .padding(8)
        .frame(minWidth: 320, maxWidth: 814, alignment: .leading)
        .background(theme.launcherMainBackground)
        .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .inset(by: 0.25)
                .stroke(
                    Color(match?.faviconBackgroundColor ?? match?.color ?? theme.foreground)
                        .opacity(0.15),
                    lineWidth: 0.5
                )
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

        // Find the search engine by name to get its isAIChat property
        if let engine = searchEngineService.getSearchEngine(byName: match!.text) {
            let prefix = engine.isAIChat ? "Ask" : "Search on"
            return "\(prefix) \(engine.name)"
        }

        // Fallback (should rarely happen)
        return "Search on \(match!.text)"
    }

    private func getIconName(match: Match?, text: String) -> String {
        if match != nil {
            return "magnifyingglass"
        }
        return isValidURL(text) ? "globe" : "magnifyingglass"
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
        "translate", "compare", "alternatives", "improve", "fix", "suggest"
    ]

    for keyword in aiKeywords {
        if lowercased.contains(keyword) {
            return true
        }
    }

    return false
}
