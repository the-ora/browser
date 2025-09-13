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

    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    var canDeleteContainers: Bool {
        do {
            let descriptor = FetchDescriptor<TabContainer>()
            let containers = try modelContext.fetch(descriptor)
            return containers.count > 1
        } catch {
            print("Error fetching containers: \(error)")
            return false
        }
    }

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext

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
        historyManager: HistoryManager
    ) {
        if let url = SearchEngineService().getSearchURLForEngine(
            engineName: engineName,
            query: query
        ) {
            openTab(url: url, historyManager: historyManager)
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
            //            if let lastAccessedTab = lastAccessedContainer.tabs.sorted(by: { $0.lastAccessedAt ?? Date() >
            //            $1.lastAccessedAt ?? Date() }).first {
            //                activeTab = lastAccessedTab
            //            } else {
            //                // No tabs, create one
            //
            //                activeTab = addTab(container: lastAccessedContainer)
            //            }
        } else {
            // No containers, create one
            let newContainer = createContainer()
            activeContainer = newContainer
            //            activeTab = addTab(container: newContainer)
        }

        //        activeTab?.maybeIsActive = true
    }

    func createContainer(name: String = "Default", emoji: String = "💩") -> TabContainer {
        let newContainer = TabContainer(name: name, emoji: emoji)
        modelContext.insert(newContainer)
        activeContainer = newContainer
        try? modelContext.save()
        //        _ = fetchContainers() // Refresh containers
        return newContainer
    }

    func renameContainer(_ container: TabContainer, name: String, emoji: String) {
        container.name = name
        container.emoji = emoji
        try? modelContext.save()
    }

    func deleteContainer(_ container: TabContainer, deleteHistory: Bool = false) -> Bool {
        do {
            let descriptor = FetchDescriptor<TabContainer>()
            let containers = try modelContext.fetch(descriptor)

            // pick a fallback container, so so we're sure the app has a different container to switch to
            guard let fallback = containers.first(where: { $0.id != container.id }) else {
                return false
            }

            // if the container we're deleting is active rn switch to the fallback and pick it's last opened tab
            if activeContainer?.id == container.id {
                if let tab = fallback.tabs
                    .sorted(by: { ($0.lastAccessedAt ?? .distantPast) > ($1.lastAccessedAt ?? .distantPast) }).first
                {
                    activateTab(tab)
                } else {
                    // if there are no tabs just activate that container
                    activateContainer(fallback)
                }
            }

            // this could be improved, but it should do for now
            // in order for this to cause issues, the user would need to have 1000+ tabs open, and then try to delete
            // the entire container
            for tab in container.tabs {
                modelContext.delete(tab)
            }

            // delete or keep history
            if deleteHistory {
                for h in container.history {
                    modelContext.delete(h)
                }
            } else {
                // detach history
                for h in container.history {
                    h.container = nil
                }
            }

            try modelContext.save()

            // finally delete the container
            modelContext.delete(container)
            try modelContext.save()

        } catch {
            print("Error deleting container: \(error.localizedDescription)")
            return false
        }

        return true
    }

    func addTab(
        title: String = "Untitled",
        url: URL = URL(string: "https://www.youtube.com/") ?? URL(string: "about:blank") ?? URL(fileURLWithPath: ""),
        container: TabContainer,
        favicon: URL? = nil,
        historyManager: HistoryManager? = nil,
        downloadManager: DownloadManager? = nil
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
            tabManager: self
        )
        modelContext.insert(newTab)
        container.tabs.append(newTab)
        activeTab?.maybeIsActive  = false
        activeTab = newTab
        activeTab?.maybeIsActive  = true
        newTab.lastAccessedAt = Date()
        container.lastAccessedAt = Date()
        try? modelContext.save()
        return newTab
    }

    func openTab(
        url: URL,
        historyManager: HistoryManager,
        downloadManager: DownloadManager? = nil
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
                    tabManager: self
                )
                modelContext.insert(newTab)
                container.tabs.append(newTab)
                activeTab?.maybeIsActive  = false
                activeTab = newTab
                activeTab?.maybeIsActive = true
                newTab.lastAccessedAt = Date()
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
                    tabManager: tabManager
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
        }
    }

    func restoreLastTab() {
        guard let undoManager = modelContext.undoManager else { return }
        undoManager.undo() // Reverts the last deletion
        try? modelContext.save() // Persist the undo operation
    }

    func activateContainer(_ container: TabContainer) {
        activeContainer = container
        container.lastAccessedAt = Date()
        // Set the most recently accessed tab in the container
        if let lastAccessedTab = container.tabs
            .sorted(by: { $0.lastAccessedAt ?? Date() > $1.lastAccessedAt ?? Date() }).first
        {
            activeTab?.maybeIsActive = false
            activeTab = lastAccessedTab
            activeTab?.maybeIsActive = true
            lastAccessedTab.lastAccessedAt = Date()
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
            // You can update the active tab’s url if needed
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
}
