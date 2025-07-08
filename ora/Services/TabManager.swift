import SwiftUI
import WebKit

// MARK: - Tab Manager
class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabId: UUID?
    
    private var webViewConfiguration: WKWebViewConfiguration
    
    var selectedTab: BrowserTab? {
        guard let selectedTabId = selectedTabId else { return nil }
        return tabs.first { $0.id == selectedTabId }
    }
    
    init() {
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
        
        self.webViewConfiguration = configuration
        
        // Create initial tab
        addTab()
    }
    
    func addTab(url: URL = URL(string: "https://www.x.com")!) {
        let newTab = BrowserTab(url: url, configuration: webViewConfiguration)
        tabs.append(newTab)
        selectedTabId = newTab.id
    }
    
    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return } // Don't close the last tab
        
        let index = tabs.firstIndex { $0.id == id } ?? 0
        tabs.remove(at: index)
        
        // Select an adjacent tab if the closed tab was selected
        if selectedTabId == id {
            let newIndex = min(index, tabs.count - 1)
            selectedTabId = tabs[newIndex].id
        }
    }
    
    func selectTab(id: UUID) {
        selectedTabId = id
    }
} 