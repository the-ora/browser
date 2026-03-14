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

    func configure(
        tabManager: TabManager,
        historyManager: HistoryManager,
        downloadManager: DownloadManager,
        appState: AppState,
        privacyMode: PrivacyMode,
        onSubmit: @escaping (String?) -> Void
    ) {
        self.tabManager = tabManager
        self.historyManager = historyManager
        self.downloadManager = downloadManager
        self.appState = appState
        self.privacyMode = privacyMode
        self.onSubmit = onSubmit
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
            appState?.showLauncher = false
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
                tabManager.openFromEngine(
                    engineName: engineName,
                    query: query ?? self.currentText,
                    historyManager: historyManager,
                    isPrivate: privacyMode.isPrivate
                )
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
        guard let tabManager, let historyManager, let downloadManager, let privacyMode else {
            return
        }
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
        guard let tabManager else { return }
        let containerId = tabManager.activeContainer?.id
        let searchEngine = searchEngineService.getDefaultSearchEngine(for: containerId)
        let engineName = searchEngine?.name ?? "Google"
        suggestions.append(
            LauncherSuggestion(
                type: .suggestedQuery,
                title: "\(text) - Search with \(engineName)",
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

    private func isAISuitableQuery(_ query: String) -> Bool {
        let lowercased = query.lowercased()

        let aiKeywords = [
            #"^(who|when|where|what|how|why)\b.*\?$"#,
            #"^\d{4}"#,
            "summarize", "rewrite", "explain", "code", "how to", "generate",
            "idea", "opinion", "feedback", "story", "joke", "email", "draft",
            "translate", "compare", "alternatives", "improve", "fix", "suggest"
        ]

        for keyword in aiKeywords where lowercased.contains(keyword) {
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
