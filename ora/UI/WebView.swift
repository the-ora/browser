import AppKit
import SwiftUI
@preconcurrency import WebKit

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            tabManager: tabManager,
            historyManager: historyManager,
            downloadManager: downloadManager,
            privacyMode: privacyMode
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        // Don't override uiDelegate - let Tab handle it
        // webView.uiDelegate = context.coordinator

        webView.autoresizingMask = [.width, .height]
        webView.layer?.isOpaque = true
        webView.layer?.drawsAsynchronously = true

        // Add mouse event handling for back/forward buttons
        setupMouseEventHandling(for: webView, coordinator: context.coordinator)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No update logic needed
    }

    // MARK: - Mouse Event Handling

    private func setupMouseEventHandling(for webView: WKWebView, coordinator: Coordinator) {
        // Store the coordinator reference for mouse event handling
        coordinator.setupMouseEventMonitoring(for: webView)
    }

    // MARK: - Coordinator for WKUIDelegate

    class Coordinator: NSObject, WKUIDelegate {
        weak var tabManager: TabManager?
        weak var historyManager: HistoryManager?
        weak var downloadManager: DownloadManager?
        weak var privacyMode: PrivacyMode?
        private var mouseEventMonitor: Any?
        private weak var webView: WKWebView?

        init(
            tabManager: TabManager?,
            historyManager: HistoryManager?,
            downloadManager: DownloadManager?,
            privacyMode: PrivacyMode
        ) {
            self.tabManager = tabManager
            self.historyManager = historyManager
            self.downloadManager = downloadManager
            self.privacyMode = privacyMode
        }

        deinit {
            if let monitor = mouseEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        // MARK: - Mouse Event Handling

        func setupMouseEventMonitoring(for webView: WKWebView) {
            self.webView = webView

            // Monitor for other mouse button events (buttons 3, 4 and 5)
            mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
                guard let self,
                      let webView = self.webView,
                      self.isEventInWebView(event, webView: webView)
                else {
                    return event
                }

                // Handle mouse button events for back/forward navigation and middle-click to open link in new tab
                switch event.buttonNumber {
                case 2: // Mouse button 3 (middle click to open link in new tab)
                    handleMiddleClick(at: event.locationInWindow, webView: webView)
                    return nil
                case 3: // Mouse button 4 (back)
                    if webView.canGoBack {
                        DispatchQueue.main.async {
                            webView.goBack()
                        }
                    }
                    return nil // Consume the event
                case 4: // Mouse button 5 (forward)
                    if webView.canGoForward {
                        DispatchQueue.main.async {
                            webView.goForward()
                        }
                    }
                    return nil // Consume the event
                default:
                    return event // Let other events pass through
                }
            }
        }

        private func handleMiddleClick(at location: NSPoint, webView: WKWebView) {
            let locationInWebView = webView.convert(location, from: nil)

            // Ensure the coordinates are within the web view bounds
            guard locationInWebView.x.isFinite, locationInWebView.y.isFinite,
                  locationInWebView.x >= 0, locationInWebView.y >= 0
            else {
                return
            }

            let jsCode = """
                (function() {
                    var element = document.elementFromPoint(\(locationInWebView.x), \(locationInWebView.y));
                    while (element && element.tagName !== 'A') {
                        element = element.parentElement;
                    }
                    return element ? element.href : null;
                })();
            """

            webView.evaluateJavaScript(jsCode) { [weak self] result, error in
                guard error == nil else {
                    print("Error evaluating JavaScript for middle-click link detection: \(error!.localizedDescription)")
                    return
                }

                if let urlString = result as? String, let url = URL(string: urlString),
                   let tabManager = self?.tabManager, let historyManager = self?.historyManager,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                {
                    DispatchQueue.main.async {
                        tabManager.openTab(
                            url: url,
                            historyManager: historyManager,
                            focusAfterOpening: false,
                            isPrivate: self?.privacyMode?.isPrivate ?? false
                        )
                    }
                }
            }
        }

        private func isEventInWebView(_ event: NSEvent, webView: WKWebView) -> Bool {
            // Convert the event location to the web view's coordinate system
            let locationInWindow = event.locationInWindow
            let locationInWebView = webView.convert(locationInWindow, from: nil)

            // Check if the event occurred within the web view's bounds
            return webView.bounds.contains(locationInWebView)
        }

        // func webView(
        //     _ webView: WKWebView,
        //     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        //     initiatedByFrame frame: WKFrameInfo,
        //     decisionHandler: @escaping (WKPermissionDecision) -> Void
        // ) {
        //     let host = origin.host
        //     print("🎥 WebKit requesting media capture for: \(host)")

        //     // Check if we already have permissions configured for this host
        //     let cameraPermission = PermissionManager.shared.getExistingPermission(for: host, type: .camera)
        //     let microphonePermission = PermissionManager.shared.getExistingPermission(for: host, type: .microphone)

        //     print("🎥 Existing permissions - Camera: \(String(describing: cameraPermission)), Microphone:
        //     \(String(describing: microphonePermission))")

        //     // If both permissions are already configured, use them
        //     if let cameraAllowed = cameraPermission, let microphoneAllowed = microphonePermission {
        //         let shouldGrant = cameraAllowed || microphoneAllowed
        //         print("🎥 Using existing permissions, granting: \(shouldGrant)")
        //         decisionHandler(shouldGrant ? .grant : .deny)
        //         return
        //     }

        //     print("🎥 Requesting new permissions...")

        //     // If permissions aren't configured, we need to request them
        //     // Since WebKit doesn't specify which media type, we'll request both
        //     Task { @MainActor in
        //         // First request camera permission
        //         PermissionManager.shared.requestPermission(
        //             for: .camera,
        //             from: host,
        //             webView: webView
        //         ) { cameraAllowed in
        //             print("🎥 Camera permission result: \(cameraAllowed)")
        //             // Then request microphone permission
        //             PermissionManager.shared.requestPermission(
        //                 for: .microphone,
        //                 from: host,
        //                 webView: webView
        //             ) { microphoneAllowed in
        //                 print("🎥 Microphone permission result: \(microphoneAllowed)")
        //                 // Grant if either permission is allowed
        //                 let shouldGrant = cameraAllowed || microphoneAllowed
        //                 print("🎥 Final decision: \(shouldGrant)")
        //                 decisionHandler(shouldGrant ? .grant : .deny)
        //             }
        //         }
        //     }
        // }

        func webView(
            _ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void
        ) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = parameters.allowsDirectories
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

            openPanel.begin { result in
                if result == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }

        // MARK: - Additional Permission Handlers

        // Note: Most permissions are handled via JavaScript interceptor
        // WebKit only provides delegates for a limited set of permissions

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = "Confirm"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        // MARK: - Handle target="_blank" and new window requests

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Handle target="_blank" links and other new window requests
            guard let url = navigationAction.request.url,
                  let tabManager = self.tabManager,
                  let historyManager = self.historyManager
            else {
                return nil
            }

            // Create a new tab in the background for the target URL
            DispatchQueue.main.async {
                tabManager.openTab(
                    url: url,
                    historyManager: historyManager,
                    downloadManager: self.downloadManager,
                    isPrivate: self.privacyMode?.isPrivate ?? false
                )
            }

            // Return nil to prevent creating a new WebView instance
            // The new tab will handle the navigation
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = "Confirm"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = "Prompt"
            alert.informativeText = prompt
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = defaultText ?? ""

            alert.accessoryView = textField

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(textField.stringValue)
            } else {
                completionHandler(nil)
            }
        }
    }
}
