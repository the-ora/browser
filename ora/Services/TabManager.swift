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

    var recentTabs: [Tab] {
        guard let container = activeContainer else { return [] }
        return Array(container.tabs
            .sorted { ($0.lastAccessedAt ?? Date.distantPast) > ($1.lastAccessedAt ?? Date.distantPast) }
            .prefix(SettingsStore.shared.maxRecentTabs)
        )
    }

    private func addSplitMembers(to tabs: inout Set<Tab>, fromContainer container: TabContainer) {
        for tileset in container.tilesets {
            if tileset.tabs.contains(where: { tabs.contains($0) }) {
                tabs.formUnion(tileset.tabs)
            }
        }
    }

    func isInSplit(tab: Tab) -> Bool {
        activeContainer?.tilesets.contains(where: {
            $0.tabs.contains(tab) && $0.tabs.contains(where: { $0.id == activeTab?.id })
        }) ?? false
    }

    var tabsToRender: [Tab] {
        guard let container = activeContainer else { return [] }
        let specialTabs = container.tabs.filter { $0.type == .pinned || $0.type == .fav || $0.isPlayingMedia }
        var combined = Set(recentTabs + specialTabs)
        addSplitMembers(to: &combined, fromContainer: container)
        return Array(combined).sorted(by: { $0.order < $1.order })
    }

    // Note: Could be made injectable via init parameter if preferred
    let tabSearchingService: TabSearchingProviding

    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    private var cleanupTimer: Timer?

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext,
        mediaController: MediaController,
        tabSearchingService: TabSearchingProviding = TabSearchingService()
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        self.mediaController = mediaController
        self.tabSearchingService = tabSearchingService

        self.modelContext.undoManager = UndoManager()
        initializeActiveContainerAndTab()

        // Start automatic cleanup timer (every minute)
        startCleanupTimer()
    }

    // MARK: - Public API's

    func search(_ text: String) -> [Tab] {
        tabSearchingService.search(
            text,
            activeContainer: activeContainer,
            modelContext: modelContext
        )
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
        var tabsToActivate = Set([tab])
        if let activeContainer, let activeTab {
            addSplitMembers(to: &tabsToActivate, fromContainer: activeContainer)
            return tabsToActivate.contains(activeTab)
        }
        return false
    }

    func togglePinTab(_ tab: Tab) {
        let opposite = tab.type == .pinned ? TabType.normal : .pinned

        tab.container
            .reorderTabs(from: tab, to: opposite, offsetTargetTypeOrder: true)

        try? modelContext.save()
    }

    func toggleFavTab(_ tab: Tab) {
        if tab.type == .fav {
            tab.switchSections(to: .normal)
        } else {
            tab.switchSections(to: .fav)
        }

        try? modelContext.save()
    }

    // MARK: - Container Public API's

    func moveTabToContainer(_ tab: Tab, toContainer: TabContainer) {
        tab.dissociateFromRelatives()
        tab.container = toContainer
        tab.order = (toContainer.tabs.map((\.order)).max() ?? -1) + 1
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

    // MARK: - Tab Public API's

    func addTab(
        title: String = "Untitled",
        /// Will Always Work
        url: URL = URL(string: "about:blank")!,
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
            order: 0,
            historyManager: historyManager,
            downloadManager: downloadManager,
            tabManager: self,
            isPrivate: isPrivate
        )
        modelContext.insert(newTab)
        container.addTab(newTab)
        activeTab?.maybeIsActive  = false
        activeTab = newTab
        activeTab?.maybeIsActive  = true
        newTab.lastAccessedAt = Date()
        container.lastAccessedAt = Date()

        // Initialize the WebView for the new active tab
        newTab.restoreTransientState(
            historyManager: historyManager ?? HistoryManager(
                modelContainer: modelContainer,
                modelContext: modelContext
            ),
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
        isPrivate: Bool,
        loadSilently: Bool = false,
        parentingTo parent: Tab? = nil
    ) -> Tab? {
        if let container = activeContainer {
            if let host = url.host {
                let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")

                let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

                let orderBase = (parent != nil ? parent!.children : container.tabs).map(\.order).max() ?? -1

                let newTab = Tab(
                    parent: parent, url: url,
                    title: cleanHost,
                    favicon: faviconURL,
                    container: container,
                    type: .normal,
                    isPlayingMedia: false,
                    order: orderBase + 1,
                    historyManager: historyManager,
                    downloadManager: downloadManager,
                    tabManager: self,
                    isPrivate: isPrivate
                )
                container.addTab(newTab)

                if focusAfterOpening {
                    activateTab(newTab)
                }
                if focusAfterOpening || loadSilently {
                    // Initialize the WebView for the new active tab
                    newTab.restoreTransientState(
                        historyManager: historyManager,
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
                return newTab
            }
        }
        return nil
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
        tab.dissociateFromRelatives()
        activeContainer?.removeTabFromTileset(tab: tab)

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
                    historyManager: historyManager,
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
                self.mediaController.removeSession(for: tab.id)
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

    func togglePiP(_ currentTab: Tab?, _ oldTab: Tab?) {
        if currentTab?.id != oldTab?.id, SettingsStore.shared.autoPiPEnabled {
            currentTab?.webView.evaluateJavaScript("window.__oraTriggerPiP(true)")
            oldTab?.webView.evaluateJavaScript("window.__oraTriggerPiP()")
        }
    }

    private func activateTabInner(_ tab: Tab) {
        // Toggle Picture-in-Picture on tab switch
        togglePiP(tab, activeTab)

        // Activate the tab
        activeTab?.maybeIsActive = false
        activeTab = tab
        activeTab?.maybeIsActive = true
        tab.lastAccessedAt = Date()
        activeContainer = tab.container
        tab.container.lastAccessedAt = Date()

        // Lazy load WebView if not ready
        if !tab.isWebViewReady {
            tab.restoreTransientState(
                historyManager: tab.historyManager ?? HistoryManager(
                    modelContainer: modelContainer,
                    modelContext: modelContext
                ),
                downloadManager: tab.downloadManager ?? DownloadManager(
                    modelContainer: modelContainer,
                    modelContext: modelContext
                ),
                tabManager: self,
                isPrivate: tab.isPrivate
            )
        }
        tab.updateHeaderColor()
        try? modelContext.save()
    }

    func activateTab(_ tab: Tab) {
        var tabsToActivate = Set([tab])
        if let activeContainer {
            addSplitMembers(to: &tabsToActivate, fromContainer: activeContainer)
        }
        for tab in tabsToActivate {
            activateTabInner(tab)
        }
    }

    /// Clean up old tabs that haven't been accessed recently to preserve memory
    func cleanupOldTabs() {
        let timeout = SettingsStore.shared.tabAliveTimeout
        // Skip cleanup if set to "Never" (365 days)
        guard timeout < 365 * 24 * 60 * 60 else { return }

        let allContainers = fetchContainers()
        for container in allContainers {
            for tab in container.tabs {
                if !tab.isAlive, tab.isWebViewReady, tab.id != activeTab?.id, !tab.isPlayingMedia, tab.type == .normal {
                    tab.destroyWebView()
                }
            }
        }
    }

    /// Completely remove old normal tabs that haven't been accessed for a long time
    func removeOldTabs() {
        let cutoffDate = Date().addingTimeInterval(-SettingsStore.shared.tabRemovalTimeout)
        let allContainers = fetchContainers()

        for container in allContainers {
            for tab in container.tabs {
                if let lastAccessed = tab.lastAccessedAt,
                   lastAccessed < cutoffDate,
                   tab.id != activeTab?.id,
                   !tab.isPlayingMedia,
                   tab.type == .normal
                {
                    closeTab(tab: tab)
                }
            }
        }
    }

    /// Start the automatic cleanup timer
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cleanupOldTabs()
                self?.removeOldTabs()
            }
        }
    }

    deinit {
        cleanupTimer?.invalidate()
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
        // Create a new tab using the existing openTab method
        guard let historyManager = tab.historyManager else { return }
        guard let newTab = openTab(
            url: tab.url,
            historyManager: historyManager,
            downloadManager: tab.downloadManager,
            focusAfterOpening: false,
            isPrivate: tab.isPrivate,
            loadSilently: true
        ) else { return }
        self.reorderTabs(from: tab, toTab: newTab)
    }
}

// MARK: - Tab Searching Providing

protocol TabSearchingProviding {
    func search(
        _ text: String,
        activeContainer: TabContainer?,
        modelContext: ModelContext
    ) -> [Tab]
}

// MARK: - Tab Searching Service

final class TabSearchingService: TabSearchingProviding {
    func search(
        _ text: String,
        activeContainer: TabContainer? = nil,
        modelContext: ModelContext
    ) -> [Tab] {
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
}
