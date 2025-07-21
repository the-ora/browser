//
//  TabScriptHandler.swift
//  ora
//
//  Created by keni on 7/21/25.
//
import WebKit


class TabScriptHandler: NSObject, WKScriptMessageHandler {
    var onChange: ((String) -> Void)?
    var tab: Tab?
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "listener",
              let jsonString = message.body as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            return
        }
        
        do {
            let update = try JSONDecoder().decode(URLUpdate.self, from: jsonData)
            DispatchQueue.main.async {
                guard let tab = self.tab else { return }
                tab.title = update.title
                tab.url = URL(string: update.href) ?? tab.url
                tab
                    .setFavicon(
                        faviconURLDefault: URL(string: update.favicon)
                    )
               
            }
            
        } catch {
            print("Failed to decode JS message: \(error)")
        }
    }
    
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
        
        // injecting listners
        let contentController = WKUserContentController()
        contentController.add(self, name: "listener")
        configuration.userContentController = contentController
        
        return configuration
    }
    
    deinit {
        // Optional cleanup
        print("TabScriptHandler deinitialized")
    }
}
