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
    weak var mediaController: MediaController?

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
                    let oldTitle = tab.title
                    tab.title = update.title
                    tab.url = URL(string: update.href) ?? tab.url
                    tab
                        .setFavicon(
                            faviconURLDefault: URL(string: update.favicon)
                        )
                    tab.updateHistory()

                    // If title changed and there are active media sessions, update them
                    if oldTitle != update.title, !update.title.isEmpty {
                        self.mediaController?.syncTitleForTab(tab.id, newTitle: update.title)
                    }
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
        } else if message.name == "mediaEvent" {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let tab = self.tab
            else { return }
            if let payload = try? JSONDecoder().decode(MediaEventPayload.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.mediaController?.receive(event: payload, from: tab)
                }
            }
        } else if message.name == "downloadExtension" {
            guard let body = message.body as? [String: Any],
                  let urlString = body["url"] as? String,
                  let url = URL(string: urlString),
                  let tab = self.tab
            else { return }
            Task {
                await downloadAndInstallExtension(from: url, tab: tab)
            }
        }
    }

    func customWKConfig(containerId: UUID, temporaryStorage: Bool = false) -> WKWebViewConfiguration {
        // Configure WebView for performance
        let configuration = WKWebViewConfiguration()
        let userAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0.1 Safari/605.1.15"
        configuration.applicationNameForUserAgent = userAgent
        configuration.allowsInlinePredictions = false

        // Enable JavaScript
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        configuration.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        configuration.preferences.setValue(true, forKey: "javaScriptEnabled")
        configuration.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
        configuration.preferences.setValue(true, forKey: "pushAPIEnabled")
        configuration.preferences.setValue(true, forKey: "notificationsEnabled")
        configuration.preferences.setValue(true, forKey: "notificationEventEnabled")
        configuration.preferences.setValue(true, forKey: "fullScreenEnabled")

        // configuration.preferences.setValue(false, forKey: "allowsAutomaticSpellingCorrection")
        // configuration.preferences.setValue(false, forKey: "allowsAutomaticTextReplacement")
        // configuration.preferences.setValue(false, forKey: "allowsAutomaticQuoteSubstitution")
        // configuration.preferences.setValue(false, forKey: "allowsAutomaticDashSubstitution")
        if temporaryStorage {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        } else {
            configuration.websiteDataStore = WKWebsiteDataStore(
                forIdentifier: containerId
            )
        }

        configuration.webExtensionController = OraExtensionManager.shared.controller

        // Performance optimizations
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Enable process pool for better memory management
//        let processPool = WKProcessPool()
//        configuration.processPool = processPool
//        // video shit
//        configuration.preferences.isElementFullscreenEnabled = true
//        if #unavailable(macOS 10.12) {
//            // Picture in picture not available on older macOS versions
//        } else {
        ////            configuration.allowsPictureInPictureMediaPlaybook = true
//        }

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
        contentController.add(self, name: "mediaEvent")
        contentController.add(self, name: "downloadExtension")
        configuration.userContentController = contentController

        return configuration
    }

    private func downloadAndInstallExtension(from url: URL, tab: Tab) async {
        logger.info("Downloading extension from: \(url.absoluteString)")

        // Download the file
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
        else {
            logger.error("Failed to download extension")
            return
        }

        // Save to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempZipURL = tempDir.appendingPathComponent("downloaded_extension.zip")
        try? data.write(to: tempZipURL)

        // Extract
        let extensionsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("extensions")
        if !FileManager.default.fileExists(atPath: extensionsDir.path) {
            try? FileManager.default.createDirectory(at: extensionsDir, withIntermediateDirectories: true)
        }

        // Create subfolder named after the file or something
        let zipName = url.deletingPathExtension().lastPathComponent
        let extractDir = extensionsDir.appendingPathComponent(zipName)
        if !FileManager.default.fileExists(atPath: extractDir.path) {
            try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        }

        // Extract using unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", extractDir.path]
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            logger.info("Extraction successful, installing extension")
            await OraExtensionManager.shared.installExtension(from: extractDir)
            // Reload the tab
            DispatchQueue.main.async {
                tab.webView.reload()
            }
        } else {
            logger.error("Extraction failed")
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempZipURL)
    }

    deinit {
        // Optional cleanup
        logger.debug("TabScriptHandler deinitialized")
    }
}
