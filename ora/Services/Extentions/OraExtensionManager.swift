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
                
                
                logger.debug("Loading extension context into controller")
                try controller.load(webContext)

                // Grant <all_urls> permission to allow injection into all pages
                if let allUrlsPattern = try? WKWebExtension.MatchPattern(string: "<all_urls>") {
                    webContext.setPermissionStatus(.grantedExplicitly, for: allUrlsPattern)
                    logger.debug("Granted <all_urls> permission for extension")
                }

                print("\(controller.extensionContexts.count) ctx")
                print("\(controller.extensions.count) ext")
                
                logger.debug("Adding extension to installed extensions list")
                installedExtensions.append(webExtension)
                
                logger.info("Extension installed successfully: \(webExtension.displayName ?? "Unknown")")
            } catch {
                logger.error("Failed to install extension from \(url.path): \(error.localizedDescription)")
                print("❌ Failed to install extension: \(error)")
            }
        }
        
    }
    
    /// Uninstall extension
    func uninstallExtension(_ webExtension: WKWebExtension) {
        logger.info("Uninstalling extension: \(webExtension.displayName ?? "Unknown")")
        
        // TODO: Implement proper unload when available
        // controller.unload(webExtension)
        
        let removedCount = installedExtensions.count
        installedExtensions.removeAll { $0 == webExtension }
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
        
        // Example: forward to Ora's tab system
        logger.debug("Message processing completed for extension '\(extensionName)'")
    }
}
