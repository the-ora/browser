//
//  ExtensionTabWrapper.swift
//  ora
//
//  Created by keni on 10/9/25.
//
import WebKit
import Foundation
import AppKit  // For NSImage


class ExtensionTabWrapper: NSObject, WKWebExtensionTab {
    weak var nativeTab: Tab?  // Weak to prevent cycles
    let id: Int
    
    init(nativeTab: Tab, id: Int) {
        self.nativeTab = nativeTab
        self.id = id
        print("[ExtTabWrapper] init wrapperId=\(id) tabId=\(nativeTab.id.uuidString) url=\(nativeTab.url.absoluteString)")
        super.init()
    }
    
    deinit {
        print("[ExtTabWrapper] deinit wrapperId=\(id)")
    }
    
//    // Required: Unique tab ID (manage via a counter in your app)
//    var id: Int {
//        get { self.id }  // Backing storage
//        // Note: This is read-only in the protocol, so no setter needed
//    }
    
    // Core bridging: Expose the webView for injection
    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        let extName = context.webExtension.displayName ?? "Unknown"
        if let tab = nativeTab {
            print("[ExtTabWrapper] webView(for:) wrapperId=\(id) tabId=\(tab.id.uuidString) ext=\(extName) url=\(tab.url.absoluteString)")
            return tab.webView
        } else {
            print("[ExtTabWrapper] webView(for:) wrapperId=\(id) ext=\(extName) tab=nil")
            return nil
        }
    }
    
    // Bridge loadURL: Translate to native method
    func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        guard let nativeTab = nativeTab else {
            completionHandler(NSError(domain: "ExtensionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tab no longer exists"]))
            return
        }
        print("[ExtTabWrapper] loadURL wrapperId=\(id) tabId=\(nativeTab.id.uuidString) target=\(url.absoluteString)")
        // Check permissions
        guard context.permissionStatus(for: .activeTab) == .grantedExplicitly else {
            completionHandler(NSError(domain: "PermissionError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No permission to load URL"]))
            return
        }
        nativeTab.loadURL(url.absoluteString)
        // Assuming loadURL is fire-and-forget; call completion with no error
        // If Tab.loadURL supports a completion, use it: nativeTab.loadURL(url.absoluteString) { error in completionHandler(error) }
        completionHandler(nil)
    }
    
//    // Bridge snapshot: Forward to native helper
//    func takeSnapshot(using options: WKWebExtension.SnapshotOptions?, for context: WKWebExtensionContext, completionHandler: @escaping (NSImage?, Error?) -> Void) {
//        guard let nativeTab = nativeTab else {
//            completionHandler(nil, NSError(domain: "ExtensionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tab no longer exists"]))
//            return
//        }
//        nativeTab.takeSnapshot { [weak self] image, error in
//            // Optional: Permission/access check here if needed
//            guard let self = self, self.nativeTab != nil else {
//                completionHandler(nil, NSError(domain: "ExtensionError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Tab invalidated during snapshot"]))
//                return
//            }
//            completionHandler(image, error)
//        }
//    }
    
    // Bridge getters: Query native state
    func url(for context: WKWebExtensionContext) -> URL? {
        return nativeTab?.url
    }
    
    func title(for context: WKWebExtensionContext) -> String? {
        return nativeTab?.title
    }
    
    // Required: Zoom factor (stub; delegate to native if available)
    func zoomFactor(for context: WKWebExtensionContext) -> Double {
        return 1.0  // Assume Tab has this; default to 1.0
    }
    
    // Required: Set zoom (stub)
    func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        guard let nativeTab = nativeTab, zoomFactor >= 0.1 && zoomFactor <= 5.0 else {
            completionHandler(NSError(domain: "ExtensionError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid zoom or tab missing"]))
            return
        }
        // Delegate to native: nativeTab.setZoomFactor(zoomFactor)
        completionHandler(nil)
    }
    
//    // Required: Execute script (stub; use WKWebView's evaluateJavaScript)
//    func executeScript(_ script: WKWebExtension.Script, for context: WKWebExtensionContext, completionHandler: @escaping (Any?, Error?) -> Void) {
//        guard let webView = webView(for: context) else {
//            completionHandler(nil, NSError(domain: "ExtensionError", code: -5, userInfo: [NSLocalizedDescriptionKey: "No web view available"]))
//            return
//        }
//        webView.evaluateJavaScript(script.source) { result, error in
//            completionHandler(result, error)
//        }
//    }
    
    // Required: Reader mode (stubs; implement if your Tab supports it)
    func setReaderModeActive(_ active: Bool, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        // Delegate to nativeTab.setReaderModeActive(active)
        completionHandler(nil)  // Or handle error
    }
    
    func isReaderModeAvailable(for context: WKWebExtensionContext) -> Bool {
        return false
    }
    
    // Add other required methods as needed (e.g., navigateBack, reload)...
}
