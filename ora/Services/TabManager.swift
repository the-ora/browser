import SwiftUI
import WebKit
import SwiftData

func defaultWKConfig() -> WKWebViewConfiguration {
    // Configure WebView for performance
    let configuration = WKWebViewConfiguration()
    let userAgent = "Mozilla/5.0 (Macintosh; arm64 Mac OS X 14_5) AppleWebKit/616.1.1 (KHTML, like Gecko) Version/18.5 Safari/616.1.1 Ora/1.0"
    configuration.applicationNameForUserAgent = userAgent

    // Enable JavaScript
    configuration.preferences.setValue(true, forKey: "javaScriptEnabled")
    configuration.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
    configuration.websiteDataStore = WKWebsiteDataStore.default()

    // Performance optimizations
    configuration.allowsAirPlayForMediaPlayback = true
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    
    // Enable process pool for better memory management
    let processPool = WKProcessPool()
    configuration.processPool = processPool
    
    // Enable media playback without user interaction
    configuration.mediaTypesRequiringUserActionForPlayback = []
    
    // Set up caching
    let websiteDataStore = WKWebsiteDataStore.default()
    configuration.websiteDataStore = websiteDataStore
    
    // GPU acceleration settings
    let preferences = WKWebpagePreferences()
    preferences.allowsContentJavaScript = true
    configuration.defaultWebpagePreferences = preferences
    return configuration
}


// MARK: - Tab Manager
@MainActor
class TabManager: ObservableObject {
    @Published var activeContainer: TabContainer?
    @Published var activeTab: Tab?
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    private var webViewConfiguration: WKWebViewConfiguration
    
    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]
    
    init(modelContainer: ModelContainer, modelContext: ModelContext) {
           self.modelContainer = modelContainer
           self.modelContext = modelContext
           self.webViewConfiguration = defaultWKConfig()
           initializeActiveContainerAndTab()
       }
    
    func isActive(_ tab: Tab)->Bool{
        
        if let activeTab = self.activeTab {
            return activeTab.id == tab.id
        }
        return false
    }
    func togglePinTab(_ tab: Tab){
        if tab.type == .pinned {
            tab.type = .normal
        }else{
            tab.type = .pinned
        }

        try? modelContext.save()
    }
    func toggleFavTab(_ tab: Tab){
        if tab.type == .fav {
            tab.type = .normal
        }else{
            tab.type = .fav
        }

        try? modelContext.save()
    }

    func getActiveTab()->Tab?{
        return self.activeTab
    }
    func moveTabToContainer(_ tab: Tab, to: TabContainer) {
        tab.container = to
        try? modelContext.save()
    }
    private func initializeActiveContainerAndTab() {
        // Ensure containers are fetched
        let containers = fetchContainers()
        
        // Get the last accessed container
        if let lastAccessedContainer = containers.first {
            activeContainer = lastAccessedContainer
            // Get the last accessed tab from the active container
            if let lastAccessedTab = lastAccessedContainer.tabs.sorted(by: { $0.lastAccessedAt ?? Date() > $1.lastAccessedAt ?? Date() }).first {
                activeTab = lastAccessedTab
            } else {
                // No tabs, create one
                activeTab = addTab(container: lastAccessedContainer)
            }
        } else {
            // No containers, create one
            let newContainer = addContainer()
            activeContainer = newContainer
            activeTab = addTab(container: newContainer)
        }
    }
    
    func addContainer(name: String = "Default", emoji: String = "💩") -> TabContainer {
        let newContainer = TabContainer(name: name, emoji: emoji)
        modelContext.insert(newContainer)
        activeContainer = newContainer
        try? modelContext.save()
//        _ = fetchContainers() // Refresh containers
        return newContainer
    }
    
    func addTab(title: String = "Untitled", url: URL = URL(string: "https://www.youtube.com/")!, container: TabContainer, favicon: URL? = nil) -> Tab {
        let cleanHost = url.host?.hasPrefix("www.") == true ? String(url.host!.dropFirst(4)) : url.host
        let newTab = Tab(
            url: url,
            title: cleanHost ?? "New Tab",
            favicon: favicon,
            container: container,
            type: .normal,
            isPlayingMedia: false,
            webViewConfiguration: webViewConfiguration,
            order: container.tabs.count + 1
        )
        modelContext.insert(newTab)
        container.tabs.append(newTab)
        activeTab = newTab
        newTab.lastAccessedAt = Date()
        container.lastAccessedAt = Date()
        try? modelContext.save()
        return newTab
    }
    func openTab(url: URL){
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
                    webViewConfiguration: webViewConfiguration,
                    order: container.tabs.count + 1
                )
                modelContext.insert(newTab)
                container.tabs.append(newTab)
                activeTab = newTab
                newTab.lastAccessedAt = Date()
                container.lastAccessedAt = Date()
                try? modelContext.save()
            }
        }
    }
    func reorderTabs(from: Tab, to: Tab) {
        from.container.reorderTabs(from: from, to: to)
        try? modelContext.save()
    }
    func switchSections(from: Tab, to: Tab) {
        from.switchSections(from: from, to: to)
        try? modelContext.save()
    }
    func closeTab(tab: Tab) {
        

        // If the closed tab was active, select another tab
        if self.activeTab?.id == tab.id {

            if let nextTab = tab.container.tabs
                .filter({ $0.id != tab.id })
                .sorted(by: { $0.lastAccessedAt ?? Date.distantPast > $1.lastAccessedAt ?? Date.distantPast })
                .first {
                

            } else if let nextContainer = containers.first(where: { $0.id != tab.container.id }) {
                self.activateContainer(nextContainer)

            } else {
                self.activeTab = nil
            }
        } else {
            self.activeTab = activeTab
        }

        modelContext.delete(tab)
            try? modelContext.save()
    }
    
    func activateContainer(_ container: TabContainer) {
        activeContainer = container
        container.lastAccessedAt = Date()
        // Set the most recently accessed tab in the container
        if let lastAccessedTab = container.tabs.sorted(by: { $0.lastAccessedAt ?? Date() > $1.lastAccessedAt ?? Date() }).first {
            activeTab = lastAccessedTab
            lastAccessedTab.lastAccessedAt = Date()
        }
        try? modelContext.save()
    }
    
    func activateTab(_ tab: Tab) {
        activeTab = tab
        tab.lastAccessedAt = Date()
        activeContainer = tab.container
        tab.container.lastAccessedAt = Date()
        try? modelContext.save()
    }
    
    
    private func fetchContainers() -> [TabContainer] {
        do {
            let descriptor = FetchDescriptor<TabContainer>(sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)])
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch containers: \(error)")
        }
        return []
    }
}



