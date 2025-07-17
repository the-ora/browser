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
    func getActiveTab()->Tab?{
        return self.activeTab
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
        let newTab = Tab(
            url: url,
            title: url.host ?? "New Tab",
            favicon: favicon,
            container: container,
            type: .normal,
            isPlayingMedia: false,
            webViewConfiguration: webViewConfiguration
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
                
                let newTab = Tab(
                    url: url,
                    title: url.host ?? "New Tab",
                    favicon: faviconURL,
                    container: container,
                    type: .normal,
                    isPlayingMedia: false,
                    webViewConfiguration: webViewConfiguration
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
    
    func closeTab(tab: Tab) {
        print("Attempting to close tab: \(tab.title) (\(tab.id))")
        
        if let activeTab = self.activeTab {
            print("Current active tab: \(activeTab.title) (\(activeTab.id))")
        } else {
            print("No active tab currently")
        }

        // If the closed tab was active, select another tab
        if self.activeTab?.id == tab.id {
            print("Closing the active tab")

            if let nextTab = tab.container.tabs
                .filter({ $0.id != tab.id })
                .sorted(by: { $0.lastAccessedAt ?? Date.distantPast > $1.lastAccessedAt ?? Date.distantPast })
                .first {
                
                print("Switching to next most recent tab in the same container: \(nextTab.title) (\(nextTab.id))")
                self.activateTab(nextTab)

            } else if let nextContainer = containers.first(where: { $0.id != tab.container.id }) {
                print("No other tabs in current container. Switching to container: \(nextContainer.name) (\(nextContainer.id))")
                self.activateContainer(nextContainer)

            } else {
                print("No other tabs or containers available. Clearing activeTab and activeContainer.")
                self.activeTab = nil
            }
        } else {
            print("Closing a background tab: \(tab.title) (\(tab.id))")
            self.activeTab = activeTab
        }

        modelContext.delete(tab)
        do {
            try modelContext.save()
            print("Tab closed and changes saved successfully.")
        } catch {
            print("Error saving after closing tab: \(error)")
        }
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

// MARK: - TabContainer
@Model
class TabContainer: ObservableObject, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var createdAt: Date
    var lastAccessedAt: Date
    
    @Relationship(deleteRule: .cascade) var tabs: [Tab] = []
    @Relationship(deleteRule: .cascade) var folders: [Folder] = []
    
    init(
        id: UUID = UUID(),
        name: String = "Default",
        isActive: Bool = true,
        emoji: String = "💩"
    ) {
        let nowDate = Date()
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdAt = nowDate
        self.lastAccessedAt = nowDate
    }
}
enum TabType: String, Codable {
    case pinned
    case fav
    case normal
}
// MARK: - Tab
@Model
class Tab: ObservableObject, Identifiable {
    var id: UUID
    var url: URL
    var title: String
    var favicon: URL? // Add favicon property
    var createdAt: Date
    var lastAccessedAt: Date?
    var isPlayingMedia: Bool
    var isLoading: Bool = false
    var type: TabType

    @Transient var backgroundColor: Color = Color(.black)
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient private var navigationDelegate: WebViewNavigationDelegate?

    @Relationship(inverse: \TabContainer.tabs) var container: TabContainer
    
    init(id: UUID = UUID(), url: URL, title: String, favicon:URL? = nil, container: TabContainer, type: TabType = .normal, isPlayingMedia:Bool = false, webViewConfiguration: WKWebViewConfiguration? = nil) {
        let nowDate = Date()
        self.id = id
        self.url = url
        self.title = title
        self.favicon = favicon
        self.createdAt = nowDate
        self.lastAccessedAt = nowDate
        self.type = type
        self.isPlayingMedia = isPlayingMedia
        self.container = container
        self.backgroundColor = Color(.black)
        // Initialize webView with provided configuration or default
        self.webView = WKWebView(
            frame: .zero,
            configuration: defaultWKConfig()
        )
        
        // Configure WebView for performance
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable layer-backed view for hardware acceleration
        webView.wantsLayer = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }
        
        // Set up navigation delegate
        setupNavigationDelegate()
        
        // Load initial URL
        DispatchQueue.main.async {
            self.webView.load(URLRequest(url: url))
        }
    }
    
    private func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.tab = self
        
        delegate.onTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                self?.title = title ?? "New Tab"
            }
        }
        delegate.onURLChange = { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.url = url
                    if let host = url.host {
                        let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)")
                        self?.favicon = faviconURL
                    }
                }
                
            }
        }
        delegate.onLoadingChange = { [weak self] isLoading in
            DispatchQueue.main.async {
                self?.isLoading = isLoading
            }
        }
        
        self.navigationDelegate = delegate
        webView.navigationDelegate = delegate
    }
    
    func loadURL(_ urlString: String) {
        var finalURLString = urlString
        
        // Add https:// if no protocol specified
        if !urlString.contains("://") {
            finalURLString = "https://" + urlString
        }
        
        if let url = URL(string: finalURLString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }
}

// MARK: - Folder
@Model
class Folder: ObservableObject, Identifiable {
    var id: UUID
    var name: String
    var isOpened: Bool
    
    @Relationship(inverse: \TabContainer.folders) var container: TabContainer
    init(
        id:UUID = UUID(),
        name:String,
        isOpened:Bool = false,
        container: TabContainer
    ){
        self.id = UUID()
        self.name = name
        self.isOpened = isOpened
        self.container = container
    }
}

