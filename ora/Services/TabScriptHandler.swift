//
//  TabScriptHandler.swift
//  ora
//
//  Created by keni on 7/21/25.
//
import os.log
import WebKit

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "TabScriptHandler")

class TabScriptHandler: NSObject, WKScriptMessageHandler {
    var onChange: ((String) -> Void)?
    var tab: Tab?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "listener" {
            guard let jsonString = message.body as? String,
                  let jsonData = jsonString.data(using: .utf8)
            else {
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
                    tab.updateHistory()
                }

            } catch {
                logger.error("Failed to decode JS message: \(error.localizedDescription)")
            }
        } else if message.name == "linkHover" {
            // Expect a String body with the hovered URL or empty string to clear
            let hovered = message.body as? String
            DispatchQueue.main.async {
                guard let tab = self.tab else { return }
                let trimmed = (hovered ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                tab.hoveredLinkURL = trimmed.isEmpty ? nil : trimmed
            }
        }
    }

    func customWKConfig(containerId: UUID,temporaryStorage:Bool=false) -> WKWebViewConfiguration {
        // Configure WebView for performance
        let configuration = WKWebViewConfiguration()
        let userAgent =
            "Mozilla/5.0 (Macintosh; arm64 Mac OS X 14_5) AppleWebKit/616.1.1 (KHTML, like Gecko) Version/18.5 Safari/616.1.1 Ora/1.0"
        configuration.applicationNameForUserAgent = userAgent

        // Enable JavaScript
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        configuration.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        configuration.preferences.setValue(true, forKey: "javaScriptEnabled")
        configuration.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
        if temporaryStorage {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }else{
            configuration.websiteDataStore = WKWebsiteDataStore(
                forIdentifier: containerId
            )
        }
      
        
        // Performance optimizations
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Enable process pool for better memory management
        let processPool = WKProcessPool()
        configuration.processPool = processPool
        // video shit
        configuration.preferences.isElementFullscreenEnabled = true
        if #unavailable(macOS 10.12) {
            // Picture in picture not available on older macOS versions
        } else {
//            configuration.allowsPictureInPictureMediaPlaybook = true
        }

        // Enable media playback without user interaction
        configuration.mediaTypesRequiringUserActionForPlayback = []


        // GPU acceleration settings
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // injecting listners
        let contentController = WKUserContentController()
        contentController.add(self, name: "listener")
        contentController.add(self, name: "linkHover")
        configuration.userContentController = contentController

        return configuration
    }

    deinit {
        // Optional cleanup
        logger.debug("TabScriptHandler deinitialized")
    }
}
