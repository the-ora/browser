//
//  OraExtensionManager.swift
//  ora
//
//  Created by keni on 9/17/25.
//


import SwiftUI
import WebKit
import os.log


// MARK: - Ora Extension Manager
class OraExtensionManager: NSObject, ObservableObject {
    static let shared = OraExtensionManager()

    public var controller: WKWebExtensionController
    private let logger = Logger(subsystem: "com.ora.browser", category: "ExtensionManager")

    @Published var installedExtensions: [WKWebExtension] = []
    var extensionMap: [URL: WKWebExtension] = [:]
    var tabManager: TabManager?
    
    override init() {
        logger.info("Initializing OraExtensionManager")
        let config = WKWebExtensionController.Configuration(identifier: UUID())
        controller = WKWebExtensionController(configuration: config)
        super.init()
        controller.delegate = self
        logger.info("OraExtensionManager initialized successfully")
    }
    
    /// Install an extension from a local file
    @MainActor
    func installExtension(from url: URL) async  {
        logger.info("Starting extension installation from URL: \(url.path)")
        
        Task {
            do {
                logger.debug("Creating WKWebExtension from resource URL")
                let webExtension = try await WKWebExtension(resourceBaseURL: url)
                logger.debug("Extension created successfully: \(webExtension.displayName ?? "Unknown")")
                
                logger.debug("Creating WKWebExtensionContext")
                let webContext = WKWebExtensionContext(for: webExtension)
                webContext.isInspectable = true

                logger.debug("Loading extension context into controller")
                try controller.load(webContext)

                // Load background content if available
                webContext.loadBackgroundContent { [self] error in
                    if let error = error {
                        self.logger.error("Failed to load background content: \(error.localizedDescription)")
                    } else {
                        self.logger.debug("Background content loaded successfully")
                    }
                }

                // Grant permissions
                if let allUrlsPattern = try? WKWebExtension.MatchPattern(string: "<all_urls>") {
                    webContext.setPermissionStatus(.grantedExplicitly, for: allUrlsPattern)
                    logger.debug("Granted <all_urls> permission for extension")
                }
                let storagePermission = WKWebExtension.Permission.storage
                webContext.setPermissionStatus(.grantedExplicitly, for: storagePermission)
                logger.debug("Granted storage permission for extension")

                print("\(controller.extensionContexts.count) ctx")
                print("\(controller.extensions.count) ext")
                
                logger.debug("Adding extension to installed extensions list")
                installedExtensions.append(webExtension)
                extensionMap[url] = webExtension
                
                logger.info("Extension installed successfully: \(webExtension.displayName ?? "Unknown")")
            } catch {
                logger.error("Failed to install extension from \(url.path): \(error.localizedDescription)")
                print("❌ Failed to install extension: \(error)")
            }
        }
        
    }
    
    /// Load all available extensions from the extensions directory
    @MainActor
    func loadAllExtensions() async {
        logger.info("Loading all available extensions")
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let extensionsDir = supportDir.appendingPathComponent("extensions")

        guard FileManager.default.fileExists(atPath: extensionsDir.path) else {
            logger.info("Extensions directory does not exist, skipping load")
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: extensionsDir, includingPropertiesForKeys: [.isDirectoryKey])
            for url in contents {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    logger.debug("Loading extension from: \(url.path)")
                    await installExtension(from: url)
                }
            }
            logger.info("Finished loading all extensions")
        } catch {
            logger.error("Failed to load extensions: \(error.localizedDescription)")
        }
    }

    /// Uninstall extension
    func uninstallExtension(_ webExtension: WKWebExtension) {
        logger.info("Uninstalling extension: \(webExtension.displayName ?? "Unknown")")

        // TODO: Implement proper unload when available
        // controller.unload(webExtension)

        let removedCount = installedExtensions.count
        installedExtensions.removeAll { $0 == webExtension }
        extensionMap = extensionMap.filter { $0.value != webExtension }
        let newCount = installedExtensions.count

        if removedCount > newCount {
            logger.info("Extension uninstalled successfully. Remaining extensions: \(newCount)")
        } else {
            logger.warning("Extension not found in installed extensions list")
        }
    }
}

// MARK: - Delegate for Permissions & Lifecycle
extension OraExtensionManager: WKWebExtensionControllerDelegate {
    
    // When extension requests new permissions
    func webExtensionController(
        _ controller: WKWebExtensionController,
        webExtension: WKWebExtension,
        requestsAccessTo permissions: [WKWebExtension.Permission]
    ) async -> Bool {
        
        let extensionName = webExtension.displayName ?? "Unknown"
        let permissionNames = permissions.map { $0.rawValue }.joined(separator: ", ")
        
        logger.info("Extension '\(extensionName)' requesting permissions: \(permissionNames)")
        
        // ✅ Show SwiftUI prompt to user
        print("🔒 Extension \(extensionName) requests: \(permissionNames)")
        
        // TODO: Replace with real SwiftUI dialog
        let granted = true // allow for now
        logger.info("Permission request for '\(extensionName)' \(granted ? "granted" : "denied")")
        
        return granted
    }
    
    // Handle background script messages
    func webExtensionController(
        _ controller: WKWebExtensionController,
        webExtension: WKWebExtension,
        didReceiveMessage message: Any,
        from context: WKWebExtensionContext
    ) {
        let extensionName = webExtension.displayName ?? "Unknown"
        logger.debug("Received message from extension '\(extensionName)': \(String(describing: message))")

        print("📩 Message from \(extensionName): \(message)")

        // Handle tab API messages
        handleTabAPIMessage(message, from: context)

        logger.debug("Message processing completed for extension '\(extensionName)'")
    }

    private func handleTabAPIMessage(_ message: Any, from context: WKWebExtensionContext) {
        guard let dict = message as? [String: Any],
              let api = dict["api"] as? String, api == "tabs",
              let method = dict["method"] as? String,
              let params = dict["params"] as? [String: Any] else {
            return
        }

        guard let tabManager = tabManager else {
            logger.error("TabManager not available for extension tab API")
            return
        }

        Task { @MainActor in
            switch method {
            case "create":
                handleTabsCreate(params: params, context: context)
            case "remove":
                handleTabsRemove(params: params, context: context)
            case "update":
                handleTabsUpdate(params: params, context: context)
            case "query":
                handleTabsQuery(params: params, context: context)
            case "get":
                handleTabsGet(params: params, context: context)
            default:
                logger.debug("Unknown tabs API method: \(method)")
            }
        }
    }

    @MainActor
    private func handleTabsCreate(params: [String: Any], context: WKWebExtensionContext) {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString),
              let container = tabManager?.activeContainer else {
            return
        }

        let isPrivate = params["incognito"] as? Bool ?? false
        let active = params["active"] as? Bool ?? true

        // Create history and download managers if needed
        let historyManager = HistoryManager(modelContainer: tabManager!.modelContainer, modelContext: tabManager!.modelContext)
        let downloadManager = DownloadManager(modelContainer: tabManager!.modelContainer, modelContext: tabManager!.modelContext)

        if active {
            tabManager?.openTab(url: url, historyManager: historyManager, downloadManager: downloadManager, isPrivate: isPrivate)
        } else {
            _ = tabManager?.addTab(url: url, container: container, historyManager: historyManager, downloadManager: downloadManager, isPrivate: isPrivate)
        }
    }

    @MainActor
    private func handleTabsRemove(params: [String: Any], context: WKWebExtensionContext) {
        guard let tabIdStrings = params["tabIds"] as? [String] else { return }

        for tabIdString in tabIdStrings {
            if let tabId = UUID(uuidString: tabIdString),
               let container = tabManager?.activeContainer,
               let tab = container.tabs.first(where: { $0.id == tabId }) {
                tabManager?.closeTab(tab: tab)
            }
        }
    }

    @MainActor
    private func handleTabsUpdate(params: [String: Any], context: WKWebExtensionContext) {
        guard let tabIdString = params["tabId"] as? String,
              let tabId = UUID(uuidString: tabIdString),
              let container = tabManager?.activeContainer,
              let tab = container.tabs.first(where: { $0.id == tabId }) else { return }

        // Update tab properties
        if let urlString = params["url"] as? String, let url = URL(string: urlString) {
            tab.url = url
            tab.webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    private func handleTabsQuery(params: [String: Any], context: WKWebExtensionContext) {
        // Query tabs
        // For now, return all tabs in active container
        guard let container = tabManager?.activeContainer else { return }
        let tabs: [[String: Any]] = container.tabs.map { tab in
            ["id": tab.id.uuidString, "url": tab.urlString, "title": tab.title, "active": tabManager?.isActive(tab) ?? false] as [String: Any]
        }
        // Note: Cannot send response back to extension via WKWebExtensionContext
        // Extensions should use events or other mechanisms
        logger.debug("Tabs query result: \(tabs)")
    }

    @MainActor
    private func handleTabsGet(params: [String: Any], context: WKWebExtensionContext) {
        guard let tabIdString = params["tabId"] as? String,
              let tabId = UUID(uuidString: tabIdString),
              let container = tabManager?.activeContainer,
              let tab = container.tabs.first(where: { $0.id == tabId }) else { return }

        let tabInfo: [String: Any] = ["id": tab.id.uuidString, "url": tab.urlString, "title": tab.title, "active": tabManager?.isActive(tab) ?? false]
        // Note: Cannot send response back to extension via WKWebExtensionContext
        logger.debug("Tab get result: \(tabInfo)")
    }
}
