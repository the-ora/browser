import SwiftData
import SwiftUI
import WebKit

// MARK: - Tab Manager

@MainActor
class TabManager: ObservableObject {
    @Published var activeContainer: TabContainer?
    @Published var activeTab: Tab?
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let mediaController: MediaController

    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext,
        mediaController: MediaController
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        self.mediaController = mediaController

        self.modelContext.undoManager = UndoManager()
        initializeActiveContainerAndTab()
    }

    func search(_ text: String) -> [Tab] {
        let activeContainerId = activeContainer?.id ?? UUID()
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        let predicate: Predicate<Tab>
        if trimmedText.isEmpty {
            predicate = #Predicate { _ in true }
        } else {
            predicate = #Predicate { tab in
                (
                    tab.urlString.localizedStandardContains(trimmedText) ||
                        tab.title
                        .localizedStandardContains(
                            trimmedText
                        )
                ) && tab.container.id == activeContainerId
            }
        }

        let descriptor = FetchDescriptor<Tab>(predicate: predicate)

        do {
            let results = try modelContext.fetch(descriptor)
            let now = Date()

            return results.sorted { result1, result2 in
                let result1Score = combinedScore(for: result1, query: trimmedText, now: now)
                let result2Score = combinedScore(for: result2, query: trimmedText, now: now)
                return result1Score > result2Score
            }

        } catch {
            return []
        }
    }

    private func combinedScore(for tab: Tab, query: String, now: Date) -> Double {
        let match = scoreMatch(tab, text: query)

        let timeInterval: TimeInterval = if let accessedAt = tab.lastAccessedAt {
            now.timeIntervalSince(accessedAt)
        } else {
            1_000_000 // far in the past → lowest recency
        }

        let recencyBoost = max(0, 1_000_000 - timeInterval)
        return Double(match * 1000) + recencyBoost
    }

    private func scoreMatch(_ tab: Tab, text: String) -> Int {
        let text = text.lowercased()
        let title = tab.title.lowercased()
        let url = tab.urlString.lowercased()

        func score(_ field: String) -> Int {
            if field == text { return 100 }
            if field.hasPrefix(text) { return 90 }
            if field.contains(text) { return 75 }
            if text.contains(field) { return 50 }
            return 0
        }

        return max(score(title), score(url))
    }

    func openFromEngine(
        engineName: SearchEngineID,
        query: String,
        historyManager: HistoryManager,
        isPrivate: Bool
    ) {
        if let url = SearchEngineService().getSearchURLForEngine(
            engineName: engineName,
            query: query
        ) {
            openTab(url: url, historyManager: historyManager, isPrivate: isPrivate)
        }
    }

    func isActive(_ tab: Tab) -> Bool {
        if let activeTab = self.activeTab {
            return activeTab.id == tab.id
        }
        return false
    }

    func togglePinTab(_ tab: Tab) {
        if tab.type == .pinned {
            tab.type = .normal
            tab.savedURL = nil
        } else {
            tab.type = .pinned
            tab.savedURL = tab.url
        }

        try? modelContext.save()
    }

    func toggleFavTab(_ tab: Tab) {
        if tab.type == .fav {
            tab.type = .normal
            tab.savedURL = nil
        } else {
            tab.type = .fav
            tab.savedURL = tab.url
        }

        try? modelContext.save()
    }

    func getActiveTab() -> Tab? {
        return self.activeTab
    }

    func moveTabToContainer(_ tab: Tab, toContainer: TabContainer) {
        tab.container = toContainer
        try? modelContext.save()
    }

    private func initializeActiveContainerAndTab() {
        // Ensure containers are fetched
        let containers = fetchContainers()

        // Get the last accessed container
        if let lastAccessedContainer = containers.first {
            activeContainer = lastAccessedContainer
            // Get the last accessed tab from the active container
            if let lastAccessedTab = lastAccessedContainer.tabs
                .sorted(by: { ($0.lastAccessedAt ?? Date.distantPast) > ($1.lastAccessedAt ?? Date.distantPast) })
                .first
            {
                activeTab = lastAccessedTab
                activeTab?.maybeIsActive = true
            }
        } else {
            let newContainer = createContainer()
            activeContainer = newContainer
        }
    }

    @discardableResult
    func createContainer(name: String = "Default", emoji: String = "•") -> TabContainer {
        let newContainer = TabContainer(name: name, emoji: emoji)
        modelContext.insert(newContainer)
        activeContainer = newContainer
        self.activeTab = nil
        try? modelContext.save()
        //        _ = fetchContainers() // Refresh containers
        return newContainer
    }

    func renameContainer(_ container: TabContainer, name: String, emoji: String) {
        container.name = name
        container.emoji = emoji
        try? modelContext.save()
    }

    func deleteContainer(_ container: TabContainer) {
        modelContext.delete(container)
    }

    func addTab(
        title: String = "Untitled",
        url: URL = URL(string: "https://www.youtube.com/") ?? URL(string: "about:blank") ?? URL(fileURLWithPath: ""),
        container: TabContainer,
        favicon: URL? = nil,
        historyManager: HistoryManager? = nil,
        downloadManager: DownloadManager? = nil,
        isPrivate: Bool
    ) -> Tab {
        let cleanHost: String? = {
            guard let host = url.host else { return nil }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }()
        let newTab = Tab(
            url: url,
            title: cleanHost ?? "New Tab",
            favicon: favicon,
            container: container,
            type: .normal,
            isPlayingMedia: false,
            order: container.tabs.count + 1,
            historyManager: historyManager,
            downloadManager: downloadManager,
            tabManager: self,
            isPrivate: isPrivate
        )
        modelContext.insert(newTab)
        container.tabs.append(newTab)
        activeTab?.maybeIsActive  = false
        activeTab = newTab
        activeTab?.maybeIsActive  = true
        newTab.lastAccessedAt = Date()
        container.lastAccessedAt = Date()

        // Initialize the WebView for the new active tab
        newTab.restoreTransientState(
            historyManger: historyManager ?? HistoryManager(modelContainer: modelContainer, modelContext: modelContext),
            downloadManager: downloadManager ?? DownloadManager(
                modelContainer: modelContainer,
                modelContext: modelContext
            ),
            tabManager: self,
            isPrivate: isPrivate
        )

        try? modelContext.save()
        return newTab
    }

    func openTab(
        url: URL,
        historyManager: HistoryManager,
        downloadManager: DownloadManager? = nil,
        focusAfterOpening: Bool = true,
        isPrivate: Bool
    ) {
        if let container = activeContainer {
            if let host = url.host {
                let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)")

                let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

                let newTab = Tab(
                    url: url,
                    title: cleanHost,
                    favicon: faviconURL,
                    container: container,
                    type: .normal,
                    isPlayingMedia: false,
                    order: container.tabs.count + 1,
                    historyManager: historyManager,
                    downloadManager: downloadManager,
                    tabManager: self,
                    isPrivate: isPrivate
                )
                modelContext.insert(newTab)
                container.tabs.append(newTab)

                if focusAfterOpening {
                    activeTab?.maybeIsActive  = false
                    activeTab = newTab
                    activeTab?.maybeIsActive = true
                    newTab.lastAccessedAt = Date()

                    // Initialize the WebView for the new active tab
                    newTab.restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager ?? DownloadManager(
                            modelContainer: modelContainer,
                            modelContext: modelContext
                        ),
                        tabManager: self,
                        isPrivate: isPrivate
                    )
                }

                container.lastAccessedAt = Date()
                try? modelContext.save()
            }
        }
    }

    func reorderTabs(from: Tab, toTab: Tab) {
        from.container.reorderTabs(from: from, to: toTab)
        try? modelContext.save()
    }

    func switchSections(from: Tab, toTab: Tab) {
        from.switchSections(from: from, to: toTab)
        try? modelContext.save()
    }

    func closeTab(tab: Tab) {
        // If the closed tab was active, select another tab
        if self.activeTab?.id == tab.id {
            if let nextTab = tab.container.tabs
                .filter({ $0.id != tab.id && $0.isWebViewReady })
                .sorted(by: { $0.lastAccessedAt ?? Date.distantPast > $1.lastAccessedAt ?? Date.distantPast })
                .first
            {
                self.activateTab(nextTab)

                //            } else if let nextContainer = containers.first(where: { $0.id != tab.container.id }) {
                //                self.activateContainer(nextContainer)
                //
            } else {
                self.activeTab = nil
            }
        } else {
            self.activeTab = activeTab
        }
        if activeTab?.isWebViewReady != nil, let historyManager = tab.historyManager,
           let downloadManager = tab.downloadManager, let tabManager = tab.tabManager
        {
            activeTab?
                .restoreTransientState(
                    historyManger: historyManager,
                    downloadManager: downloadManager,
                    tabManager: tabManager,
                    isPrivate: tab.isPrivate
                )
        }
        tab.stopMedia { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if tab.type == .normal {
                    self.modelContext.delete(tab)
                } else {
                    tab.isWebViewReady = false
                    tab.destroyWebView()
                }
                try? self.modelContext.save()
            }
        }
        self.activeTab?.maybeIsActive = true
    }

    func closeActiveTab() {
        if let tab = activeTab {
            closeTab(tab: tab)
        } else {
            NSApp.keyWindow?.close()
        }
    }

    func restoreLastTab() {
        guard let undoManager = modelContext.undoManager else { return }
        undoManager.undo() // Reverts the last deletion
        try? modelContext.save() // Persist the undo operation
    }

    func activateContainer(_ container: TabContainer, activateLastAccessedTab: Bool = true) {
        activeContainer = container
        container.lastAccessedAt = Date()

        // Set the most recently accessed tab in the container
        if let lastAccessedTab = container.tabs
            .sorted(by: { $0.lastAccessedAt ?? Date() > $1.lastAccessedAt ?? Date() }).first,
            lastAccessedTab.isWebViewReady
        {
            activeTab?.maybeIsActive = false
            activeTab = lastAccessedTab
            activeTab?.maybeIsActive = true
            lastAccessedTab.lastAccessedAt = Date()
        } else {
            activeTab = nil
        }

        try? modelContext.save()
    }

    func activateTab(_ tab: Tab) {
        activeTab?.maybeIsActive = false
        activeTab = tab
        activeTab?.maybeIsActive = true
        tab.lastAccessedAt = Date()
        activeContainer = tab.container
        tab.container.lastAccessedAt = Date()
        tab.updateHeaderColor()
        try? modelContext.save()
    }

    // Activate a tab by its persistent id. If the tab is in a
    // different container, also activate that container.
    func activateTab(id: UUID) {
        let allContainers = fetchContainers()
        for container in allContainers {
            if let tab = container.tabs.first(where: { $0.id == id }) {
                activateContainer(container)
                activateTab(tab)
                return
            }
        }
    }

    func selectTabAtIndex(_ index: Int) {
        guard let container = activeContainer else { return }

        // Match the sidebar ordering: favorites, then pinned, then normal tabs
        // All sorted by order in descending order
        let favoriteTabs = container.tabs
            .filter { $0.type == .fav }
            .sorted(by: { $0.order > $1.order })

        let pinnedTabs = container.tabs
            .filter { $0.type == .pinned }
            .sorted(by: { $0.order > $1.order })

        let normalTabs = container.tabs
            .filter { $0.type == .normal }
            .sorted(by: { $0.order > $1.order })

        // Combine all tabs in the same order as the sidebar
        let allTabs = favoriteTabs + pinnedTabs + normalTabs

        // Handle special case: Command+9 selects the last tab
        let targetIndex = (index == 9) ? allTabs.count - 1 : index - 1

        // Validate index is within bounds
        guard targetIndex >= 0, targetIndex < allTabs.count else { return }

        let targetTab = allTabs[targetIndex]
        activateTab(targetTab)
    }

    private func fetchContainers() -> [TabContainer] {
        do {
            let descriptor = FetchDescriptor<TabContainer>(sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)])
            return try modelContext.fetch(descriptor)
        } catch {
            // Failed to fetch containers
        }
        return []
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "listener",
           let url = message.body as? String
        {
            // You can update the active tab's url if needed
            DispatchQueue.main.async {
                if let validURL = URL(string: url) {
                    self.activeTab?.url = validURL
                } else if let fallbackURL = self.activeTab?.url {
                    self.activeTab?.url = fallbackURL
                } else if let blankURL = URL(string: "about:blank") {
                    self.activeTab?.url = blankURL
                }
            }
        }
    }

    func duplicateTab(_ tab: Tab) {
        // Get all tabs of the same type, sorted by order (descending)
        let sameTypeTabs = tab.container.tabs
            .filter { $0.type == tab.type }
            .sorted(by: { $0.order > $1.order })

        // Find the position of the original tab using its unique ID
        if let originalIndex = sameTypeTabs.firstIndex(where: { $0.id == tab.id }) {
            // Debug: Print the order values to understand the current state
            print("originalIndex: \(originalIndex)")
            print("sameTypeTabs.count: \(sameTypeTabs.count)")
            print("Original tab order: \(tab.order)")

            // Print all tab orders for debugging
            for (index, t) in sameTypeTabs.enumerated() {
                print("Tab \(index): order = \(t.order)")
            }

            // Calculate the correct order for the duplicated tab
            // Since tabs are sorted in descending order, we want to place it after the original
            let duplicatedOrder: Int

            if originalIndex < sameTypeTabs.count - 1 {
                // There's a tab after the original, create a unique order between them
                let nextTab = sameTypeTabs[originalIndex + 1]
                // Create a value that's between tab.order and nextTab.order
                if tab.order - nextTab.order > 1 {
                    // There's a gap, use the midpoint
                    duplicatedOrder = (tab.order + nextTab.order) / 2
                    print("Using midpoint. Duplicated order: \(duplicatedOrder)")
                } else {
                    // They're consecutive, we need to shift all tabs after the original down by 1
                    duplicatedOrder = tab.order - 1
                    print("Tabs are consecutive, shifting subsequent tabs down. Duplicated order: \(duplicatedOrder)")

                    // Shift all tabs after the original position down by 1
                    for i in (originalIndex + 1) ..< sameTypeTabs.count {
                        let tabToShift = sameTypeTabs[i]
                        print("Shifting tab \(i) from order \(tabToShift.order) to \(tabToShift.order - 1)")
                        tabToShift.order = tabToShift.order - 1
                    }
                }
            } else {
                // Original is the last tab, subtract 1
                duplicatedOrder = tab.order - 1
                print("Original is last, duplicated order: \(duplicatedOrder)")
            }

            // Create a new tab with the same properties as the original tab
            let duplicatedTab = Tab(
                url: tab.url,
                title: tab.title,
                favicon: tab.favicon,
                container: tab.container,
                type: tab.type,
                isPlayingMedia: tab.isPlayingMedia,
                order: duplicatedOrder,
                historyManager: tab.historyManager,
                downloadManager: tab.downloadManager,
                tabManager: self,
                isPrivate: tab.isPrivate
            )

            // Set up the navigation delegate for the duplicated tab
            duplicatedTab.setupNavigationDelegate()

            // Mark the web view as ready
            duplicatedTab.isWebViewReady = true

            // Add the duplicated tab to the container - let the order property determine position
            tab.container.tabs.append(duplicatedTab)

            // Save the context to persist the order
            try? modelContext.save()

            // Load the same URL as the original tab using the URL directly
            duplicatedTab.webView.load(URLRequest(url: tab.url))
        }
    }
}
