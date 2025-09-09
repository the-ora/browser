import Foundation
import WebKit

class PermissionInterceptor: NSObject, WKScriptMessageHandler {
    static let shared = PermissionInterceptor()

    override private init() {
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let permissionType = body["permission"] as? String,
              let host = body["host"] as? String,
              let callbackId = body["callbackId"] as? String
        else {
            return
        }

        guard let permission = mapJSPermissionToKind(permissionType) else {
            // Unknown permission type, deny by default
            sendPermissionResponse(to: message.webView, callbackId: callbackId, allowed: false)
            return
        }

        Task { @MainActor in
            PermissionManager.shared.requestPermission(
                for: permission,
                from: host,
                webView: message.webView!
            ) { allowed in
                self.sendPermissionResponse(to: message.webView, callbackId: callbackId, allowed: allowed)
            }
        }
    }

    private func mapJSPermissionToKind(_ jsPermission: String) -> PermissionKind? {
        switch jsPermission.lowercased() {
        case "geolocation": return .location
        case "notifications": return .notifications
        case "clipboard-read", "clipboard-write": return .clipboard
        case "background-sync": return .backgroundSync
        case "persistent-storage": return .fileEditing
        case "midi": return .midiDevice
        case "camera": return .camera
        case "microphone": return .microphone
        default: return nil
        }
    }

    private func sendPermissionResponse(to webView: WKWebView?, callbackId: String, allowed: Bool) {
        let script = """
        if (window.oraPermissionCallbacks && window.oraPermissionCallbacks['\(callbackId)']) {
            window.oraPermissionCallbacks['\(callbackId)'](\(allowed));
            delete window.oraPermissionCallbacks['\(callbackId)'];
        }
        """

        DispatchQueue.main.async {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    static let interceptorScript = """
    // Ora Permission Interceptor
    (function() {
        // Store callbacks
        window.oraPermissionCallbacks = {};
        let callbackCounter = 0;

        // Helper function to request permission
        function requestOraPermission(permission, originalMethod, ...args) {
            const callbackId = 'callback_' + (++callbackCounter);
            const host = window.location.hostname;

            return new Promise((resolve, reject) => {
                window.oraPermissionCallbacks[callbackId] = resolve;

                // Send message to native code
                window.webkit.messageHandlers.oraPermissionHandler.postMessage({
                    permission: permission,
                    host: host,
                    callbackId: callbackId
                });

                // Timeout after 30 seconds
                setTimeout(() => {
                    if (window.oraPermissionCallbacks[callbackId]) {
                        delete window.oraPermissionCallbacks[callbackId];
                        reject(new Error('Permission request timeout'));
                    }
                }, 30000);
            });
        }

        // Intercept Geolocation API
        if (navigator.geolocation) {
            const originalGetCurrentPosition = navigator.geolocation.getCurrentPosition;
            const originalWatchPosition = navigator.geolocation.watchPosition;

            navigator.geolocation.getCurrentPosition = function(success, error, options) {
                requestOraPermission('geolocation').then(allowed => {
                    if (allowed) {
                        originalGetCurrentPosition.call(this, success, error, options);
                    } else if (error) {
                        error({ code: 1, message: 'Permission denied' });
                    }
                }).catch(err => {
                    if (error) error({ code: 2, message: err.message });
                });
            };

            navigator.geolocation.watchPosition = function(success, error, options) {
                requestOraPermission('geolocation').then(allowed => {
                    if (allowed) {
                        return originalWatchPosition.call(this, success, error, options);
                    } else if (error) {
                        error({ code: 1, message: 'Permission denied' });
                    }
                    return -1;
                }).catch(err => {
                    if (error) error({ code: 2, message: err.message });
                    return -1;
                });
            };
        }

        // Intercept Notification API
        if (window.Notification) {
            const originalRequestPermission = Notification.requestPermission;

            Notification.requestPermission = function() {
                return requestOraPermission('notifications').then(allowed => {
                    return allowed ? 'granted' : 'denied';
                });
            };
        }

        // Intercept Clipboard API
        if (navigator.clipboard) {
            const originalReadText = navigator.clipboard.readText;
            const originalWriteText = navigator.clipboard.writeText;

            navigator.clipboard.readText = function() {
                return requestOraPermission('clipboard-read').then(allowed => {
                    if (allowed) {
                        return originalReadText.call(this);
                    } else {
                        throw new Error('Permission denied');
                    }
                });
            };

            navigator.clipboard.writeText = function(text) {
                return requestOraPermission('clipboard-write').then(allowed => {
                    if (allowed) {
                        return originalWriteText.call(this, text);
                    } else {
                        throw new Error('Permission denied');
                    }
                });
            };
        }

        // Intercept Service Worker registration (for background sync)
        if (navigator.serviceWorker) {
            const originalRegister = navigator.serviceWorker.register;

            navigator.serviceWorker.register = function(scriptURL, options) {
                return requestOraPermission('background-sync').then(allowed => {
                    if (allowed) {
                        return originalRegister.call(this, scriptURL, options);
                    } else {
                        throw new Error('Permission denied');
                    }
                });
            };
        }

        // Intercept MIDI API
        if (navigator.requestMIDIAccess) {
            const originalRequestMIDIAccess = navigator.requestMIDIAccess;

            navigator.requestMIDIAccess = function(options) {
                return requestOraPermission('midi').then(allowed => {
                    if (allowed) {
                        return originalRequestMIDIAccess.call(this, options);
                    } else {
                        throw new Error('Permission denied');
                    }
                });
            };
        }
    })();
    """

    func addToWebViewConfiguration(_ configuration: WKWebViewConfiguration) {
        // Add message handler
        configuration.userContentController.add(self, name: "oraPermissionHandler")

        // Add interceptor script
        let script = WKUserScript(
            source: Self.interceptorScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)
    }
}
