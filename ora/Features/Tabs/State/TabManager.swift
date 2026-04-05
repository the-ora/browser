import SwiftData
import SwiftUI

// MARK: - Tab Manager

private struct ClosedTabSnapshot {
    let id: UUID
    let containerID: UUID
    let url: URL
    let savedURL: URL?
    let title: String
    let favicon: URL?
    let faviconLocalFile: URL?
    let createdAt: Date
    let lastAccessedAt: Date?
    let type: TabType
    let order: Int
    let backgroundColorHex: String
    let isPrivate: Bool

    init(tab: Tab) {
        id = tab.id
        containerID = tab.container.id
        url = tab.url
        savedURL = tab.savedURL
        title = tab.title
        favicon = tab.favicon
        faviconLocalFile = tab.faviconLocalFile
        createdAt = tab.createdAt
        lastAccessedAt = tab.lastAccessedAt
        type = tab.type
        order = tab.order
        backgroundColorHex = tab.backgroundColorHex
        isPrivate = tab.isPrivate
    }
}

@MainActor
// swiftlint:disable:next type_body_length
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

    /// Note: Could be made injectable via init parameter if preferred
    let tabSearchingService: TabSearchingProviding

    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    private var cleanupTimer: Timer?
    private var recentlyClosedTabs: [ClosedTabSnapshot] = []
    private let maxRecentlyClosedTabs = 5

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

    // MARK: - Container Public API's

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
        let containerId = container.id
        Task { @MainActor in
            try PasswordManagerService.shared.deleteEntries(for: containerId)

            await PrivacyService.clearAllWebsiteData(for: containerId)

            guard let persistedContainer = fetchContainer(id: containerId) else {
                SettingsStore.shared.removeContainerSettings(for: containerId)
                return
            }

            let wasActiveContainer = activeContainer?.id == containerId
            prepareForContainerDeletion(isActiveContainer: wasActiveContainer)
            deleteContainerContents(persistedContainer, containerId: containerId)

            // Save child deletions before deleting the container.
            // In practice, SwiftData can fail when the parent and children are
            // removed in the same save pass while non-optional inverse
            // relationships still exist.
            try? modelContext.save()

            guard let containerToDelete = fetchContainer(id: containerId) else {
                SettingsStore.shared.removeContainerSettings(for: containerId)
                activateFallbackContainerIfNeeded(afterDeletingActiveContainer: wasActiveContainer)
                return
            }

            modelContext.delete(containerToDelete)
            try? modelContext.save()
            SettingsStore.shared.removeContainerSettings(for: containerId)

            activateFallbackContainerIfNeeded(afterDeletingActiveContainer: wasActiveContainer)
        }
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
        // Will Always Work
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

    @discardableResult
    func openTab(
        url: URL,
        historyManager: HistoryManager,
        downloadManager: DownloadManager? = nil,
        focusAfterOpening: Bool = true,
        isPrivate: Bool,
        loadSilently: Bool = false
    ) -> Tab? {
        if let container = activeContainer {
            if let host = url.host {
                let faviconURL = FaviconService.shared.faviconURL(for: host)

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

    func closeTab(tab: Tab, shouldTrackForRestore: Bool = true) {
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
        if shouldTrackForRestore, tab.type == .normal {
            trackRecentlyClosedTab(tab)
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
        guard let snapshot = recentlyClosedTabs.popLast() else { return }
        let container = fetchContainers()
            .first(where: { $0.id == snapshot.containerID }) ?? activeContainer ?? createContainer()

        shiftRestoredTabOrders(in: container, restoring: snapshot)

        let restoredTab = Tab(
            id: snapshot.id,
            url: snapshot.url,
            title: snapshot.title,
            favicon: snapshot.favicon,
            container: container,
            type: snapshot.type,
            order: snapshot.order,
            tabManager: self,
            isPrivate: snapshot.isPrivate
        )
        restoredTab.savedURL = snapshot.savedURL
        restoredTab.faviconLocalFile = snapshot.faviconLocalFile
        restoredTab.createdAt = snapshot.createdAt
        restoredTab.lastAccessedAt = snapshot.lastAccessedAt
        restoredTab.backgroundColorHex = snapshot.backgroundColorHex

        modelContext.insert(restoredTab)
        container.tabs.append(restoredTab)
        activateTab(restoredTab)
        try? modelContext.save()
    }

    func togglePiP(_ currentTab: Tab?, _ oldTab: Tab?) {
        if currentTab?.id != oldTab?.id, SettingsStore.shared.autoPiPEnabled {
            currentTab?.evaluateJavaScript("window.__oraTriggerPiP(true)")
            oldTab?.evaluateJavaScript("window.__oraTriggerPiP()")
        }
    }

    func activateTab(_ tab: Tab) {
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
                    closeTab(tab: tab, shouldTrackForRestore: false)
                }
            }
        }
    }

    /// Remove tabs in containers that have a per-space autoClearTabsAfter setting
    func autoClearContainerTabs() {
        let settings = SettingsStore.shared
        let allContainers = fetchContainers()

        for container in allContainers {
            let policy = settings.autoClearTabsAfter(for: container.id)
            guard let timeout = policy.seconds else { continue }

            let cutoffDate = Date().addingTimeInterval(-timeout)
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
                self?.autoClearContainerTabs()
            }
        }
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    /// Activate a tab by its persistent id. If the tab is in a
    /// different container, also activate that container.
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

    func refreshPrivacySettings(for containerId: UUID) {
        guard let container = fetchContainer(id: containerId) else { return }

        let loadedTabs = container.tabs.filter(\.isWebViewReady)
        guard !loadedTabs.isEmpty else { return }

        for tab in loadedTabs {
            tab.refreshBrowserPageForPrivacySettings()
        }
    }

    private func trackRecentlyClosedTab(_ tab: Tab) {
        recentlyClosedTabs.append(ClosedTabSnapshot(tab: tab))
        if recentlyClosedTabs.count > maxRecentlyClosedTabs {
            recentlyClosedTabs.removeFirst(recentlyClosedTabs.count - maxRecentlyClosedTabs)
        }
    }

    private func shiftRestoredTabOrders(in container: TabContainer, restoring snapshot: ClosedTabSnapshot) {
        for tab in container.tabs where tab.type == snapshot.type && tab.order >= snapshot.order {
            tab.order += 1
        }
    }
}

private extension TabManager {
    func fetchContainer(id: UUID) -> TabContainer? {
        let descriptor = FetchDescriptor<TabContainer>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    func prepareForContainerDeletion(isActiveContainer: Bool) {
        guard isActiveContainer else { return }

        activeTab?.maybeIsActive = false
        activeTab = nil
        activeContainer = nil
    }

    func deleteContainerContents(_ container: TabContainer, containerId: UUID) {
        for tab in Array(container.tabs) {
            if tab.isWebViewReady {
                tab.destroyWebView()
            }
            mediaController.removeSession(for: tab.id)
            modelContext.delete(tab)
        }

        for folder in Array(container.folders) {
            modelContext.delete(folder)
        }

        for history in fetchHistory(for: containerId) {
            modelContext.delete(history)
        }
    }

    func activateFallbackContainerIfNeeded(afterDeletingActiveContainer wasActiveContainer: Bool) {
        guard wasActiveContainer else { return }

        if let nextContainer = fetchContainers().first {
            activateContainer(nextContainer)
        } else {
            _ = createContainer()
        }
    }

    func fetchHistory(for containerId: UUID) -> [History] {
        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate { $0.container?.id == containerId }
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }
}
