import SwiftUI

@MainActor
class LauncherViewModel: ObservableObject {
    let searchEngineService = SearchEngineService()

    @Published var suggestions: [LauncherSuggestion] = []
    @Published var focusedElement: UUID = .init()

    /// Kept in sync with the view's text binding so closures can read current input.
    var currentText: String = ""

    private let debouncer = Debouncer(delay: 0.2)

    // Dependencies injected from the view layer
    private(set) var tabManager: TabManager?
    private(set) var historyManager: HistoryManager?
    private(set) var downloadManager: DownloadManager?
    private(set) var appState: AppState?
    private(set) var privacyMode: PrivacyMode?
    private(set) var onSubmit: ((String?) -> Void)?
    private(set) var onDismiss: (() -> Void)?
    var navigateInCurrentTab: Bool = false

    func configure(
        tabManager: TabManager,
        historyManager: HistoryManager,
        downloadManager: DownloadManager,
        appState: AppState,
        privacyMode: PrivacyMode,
        onSubmit: @escaping (String?) -> Void,
        onDismiss: (() -> Void)? = nil,
        navigateInCurrentTab: Bool = false
    ) {
        self.tabManager = tabManager
        self.historyManager = historyManager
        self.downloadManager = downloadManager
        self.appState = appState
        self.privacyMode = privacyMode
        self.onSubmit = onSubmit
        self.onDismiss = onDismiss
        self.navigateInCurrentTab = navigateInCurrentTab
    }

    // MARK: - Search Logic

    func searchHandler(_ text: String) {
        guard let tabManager, let historyManager else { return }

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

    func defaultSuggestions() -> [LauncherSuggestion] {
        guard let tabManager else { return [] }
        let containerId = tabManager.activeContainer?.id
        let searchEngine = searchEngineService.getDefaultSearchEngine(for: containerId)
        let engineName = searchEngine?.name ?? "Google"
        return [
            LauncherSuggestion(
                type: .suggestedQuery, title: "Search on \(engineName)",
                action: { [weak self] in self?.onSubmit?(nil) }
            ),
            createAISuggestion(engineName: .grok),
            createAISuggestion(engineName: .chatgpt),
            createAISuggestion(engineName: .claude),
            createAISuggestion(engineName: .gemini)
        ]
    }

    func executeCommand() {
        if let suggestion = suggestions.first(where: { $0.id == focusedElement }) {
            suggestion.action()
            onDismiss?()
        }
    }

    func moveFocusedElement(_ dir: MoveDirection) {
        guard let idx = suggestions.firstIndex(where: { $0.id == focusedElement }) else { return }
        let offset = dir == .up ? -1 : 1
        let newIndex = (idx + offset + suggestions.count) % suggestions.count
        focusedElement = suggestions[newIndex].id
    }

    // MARK: - Private Helpers

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

        return LauncherSuggestion(
            type: .aiChat,
            title: query ?? engine.name,
            name: engine.name,
            icon: engine.icon.isEmpty ? nil : engine.icon,
            color: engine.color,
            engineForegroundColor: engine.foregroundColor,
            action: { [weak self] in
                guard let self, let tabManager = self.tabManager,
                      let historyManager = self.historyManager,
                      let privacyMode = self.privacyMode
                else { return }
                if self.navigateInCurrentTab, let tab = tabManager.activeTab {
                    if let url = self.searchEngineService.getSearchURLForEngine(
                        engineName: engineName,
                        query: query ?? self.currentText
                    ) {
                        tab.loadURL(url.absoluteString)
                    }
                } else {
                    tabManager.openFromEngine(
                        engineName: engineName,
                        query: query ?? self.currentText,
                        historyManager: historyManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            }
        )
    }

    private func appendOpenTabs(_ tabs: [Tab], itemsCount: inout Int) {
        guard let tabManager, let historyManager, let downloadManager, let privacyMode else {
            return
        }
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
        guard let tabManager, let historyManager, let privacyMode else {
            return
        }
        let finalURL: URL? = if let candidateURL = URL(string: text), candidateURL.scheme != nil,
                                candidateURL.host != nil
        {
            candidateURL
        } else if isValidURL(text) {
            constructURL(from: text)
        } else {
            nil
        }
        guard let url = finalURL else { return }
        let navigateCurrent = self.navigateInCurrentTab
        suggestions.append(
            LauncherSuggestion(
                type: .suggestedLink,
                title: text,
                url: url,
                action: {
                    if navigateCurrent {
                        tabManager.activeTab?.loadURL(url.absoluteString)
                    } else {
                        tabManager.openTab(
                            url: url,
                            historyManager: historyManager,
                            isPrivate: privacyMode.isPrivate
                        )
                    }
                }
            )
        )
    }

    private func appendSearchWithDefaultEngineSuggestion(_ text: String) {
        guard let tabManager else { return }
        let containerId = tabManager.activeContainer?.id
        let searchEngine = searchEngineService.getDefaultSearchEngine(for: containerId)
        let engineName = searchEngine?.name ?? "Google"
        suggestions.append(
            LauncherSuggestion(
                type: .suggestedQuery,
                title: "\(text) - \(engineName)",
                action: { [weak self] in self?.onSubmit?(nil) }
            )
        )
    }

    private func requestAutoSuggestions(_ text: String, insertAt: Int) {
        guard let tabManager else { return }
        let containerId = tabManager.activeContainer?.id
        debouncer.run { [weak self] in
            guard let self else { return }
            let searchEngine = await self.searchEngineService.getDefaultSearchEngine(
                for: containerId
            )
            if let autoSuggestions = searchEngine?.autoSuggestions {
                let searchSuggestions = await autoSuggestions(text)
                await MainActor.run {
                    var localCount = 0
                    for searchSuggestion in searchSuggestions {
                        if localCount == 3 { break }
                        let insertIndex = insertAt + localCount
                        let suggestion = LauncherSuggestion(
                            type: .suggestedQuery,
                            title: searchSuggestion,
                            action: { [weak self] in self?.onSubmit?(searchSuggestion) }
                        )
                        if insertIndex <= self.suggestions.count {
                            self.suggestions.insert(suggestion, at: insertIndex)
                        } else {
                            self.suggestions.append(suggestion)
                        }
                        localCount += 1
                    }
                }
            }
        }
    }

    private func appendHistorySuggestions(_ histories: [History], itemsCount: inout Int) {
        guard let tabManager, let historyManager, let privacyMode else { return }
        let navigateCurrent = self.navigateInCurrentTab
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
                        if navigateCurrent {
                            tabManager.activeTab?.loadURL(history.url.absoluteString)
                        } else {
                            tabManager.openTab(
                                url: history.url,
                                historyManager: historyManager,
                                isPrivate: privacyMode.isPrivate
                            )
                        }
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

    private func isAISuitableQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let words = lowercased.split(separator: " ")

        // Negative signals: single words and URLs are not AI queries
        if words.count <= 1 { return false }
        if isValidURL(trimmed) { return false }

        // Starts with a question word
        let questionPrefixes = [
            "who ", "what ", "where ", "when ", "how ", "why ", "which ",
            "is ", "are ", "can ", "does ", "do ", "should ", "would ",
            "could ", "will ", "was ", "were ", "has ", "have "
        ]
        if questionPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }

        // Ends with a question mark
        if trimmed.hasSuffix("?") {
            return true
        }

        // Imperative / command phrases
        let imperativePhrases = [
            "write me", "help me", "create a", "give me", "list of",
            "make a", "tell me", "show me", "find me", "build a",
            "design a", "plan a", "write a", "make me", "help with"
        ]
        if imperativePhrases.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // Action keywords
        let actionKeywords = [
            "summarize", "rewrite", "explain", "generate", "how to",
            "translate", "compare", "alternatives", "improve", "suggest",
            "recommend", "analyze", "convert", "calculate", "define",
            "describe", "simplify", "debug", "optimize", "refactor",
            "review", "draft", "code", "idea", "opinion", "story",
            "joke", "email"
        ]
        if actionKeywords.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // Natural language heuristic: 4+ words likely conversational
        if words.count >= 4 {
            return true
        }

        return false
    }
}

private class Debouncer {
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
