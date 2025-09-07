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
    // Tracks which frames within the page are currently reporting active media playback.
    // We aggregate across frames to avoid false negatives when one iframe pauses while another continues.
    private var playingFrameIds = Set<String>()

    // Large JS moved out of defaultWKConfig() to keep function body under SwiftLint limits.
    private static let mediaDetectionScript: String = """
    (function() {
        // Stable per-frame identifier so native side can aggregate state across frames
        const FRAME_ID = (function() {
            try {
                if (typeof window.__oraFrameId === 'string') return window.__oraFrameId;
                const prefix = (window.top === window) ? 'main' : 'frame';
                const id = prefix + '-' + Math.random().toString(36).slice(2) + '-' + Date.now();
                window.__oraFrameId = id;
                return id;
            } catch (e) {
                return 'frame-' + Math.random().toString(36).slice(2);
            }
        })();

        let lastMediaState = false;
        let debounceTimer = null;

        function isElementAudible(el) {
            // Consider readyState to filter out elements that aren't actually playing yet
            const hasData = (typeof el.readyState === 'number') ? (el.readyState >= 2) : true;
            return !el.paused && el.currentTime > 0 && !el.muted && el.volume > 0 && hasData && !el.seeking;
        }

        function updateMediaState() {
            const mediaElements = document.querySelectorAll('video, audio');
            let isPlaying = false;

            for (const media of mediaElements) {
                if (isElementAudible(media)) {
                    isPlaying = true;
                    break;
                }
            }

            if (isPlaying !== lastMediaState) {
                lastMediaState = isPlaying;
                try {
                    window.webkit.messageHandlers.mediaState.postMessage({ frameId: FRAME_ID, isPlaying });
                } catch (e) {
                    // no-op
                }
            }
        }

        function debouncedUpdateMediaState() {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(updateMediaState, 100);
        }

        function setupMediaListeners() {
            const mediaElements = document.querySelectorAll('video, audio');
            mediaElements.forEach(media => {
                media.addEventListener('play', debouncedUpdateMediaState);
                media.addEventListener('playing', debouncedUpdateMediaState);
                media.addEventListener('pause', debouncedUpdateMediaState);
                media.addEventListener('ended', debouncedUpdateMediaState);
                media.addEventListener('volumechange', debouncedUpdateMediaState);
                media.addEventListener('loadeddata', debouncedUpdateMediaState);
                media.addEventListener('timeupdate', debouncedUpdateMediaState);
                media.addEventListener('seeking', debouncedUpdateMediaState);
                media.addEventListener('seeked', debouncedUpdateMediaState);
                media.addEventListener('ratechange', debouncedUpdateMediaState);
            });
        }

        // Initial check and setup
        setTimeout(updateMediaState, 500);
        setupMediaListeners();

        // Monitor for dynamically added media elements
        const observer = new MutationObserver((mutations) => {
            let hasNewMedia = false;
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node && node.nodeType === Node.ELEMENT_NODE) {
                        const element = node;
                        if (element.tagName === 'VIDEO' || element.tagName === 'AUDIO') {
                            hasNewMedia = true;
                            element.addEventListener('play', debouncedUpdateMediaState);
                            element.addEventListener('playing', debouncedUpdateMediaState);
                            element.addEventListener('pause', debouncedUpdateMediaState);
                            element.addEventListener('ended', debouncedUpdateMediaState);
                            element.addEventListener('volumechange', debouncedUpdateMediaState);
                            element.addEventListener('loadeddata', debouncedUpdateMediaState);
                            element.addEventListener('timeupdate', debouncedUpdateMediaState);
                            element.addEventListener('seeking', debouncedUpdateMediaState);
                            element.addEventListener('seeked', debouncedUpdateMediaState);
                            element.addEventListener('ratechange', debouncedUpdateMediaState);
                        }
                        const mediaElements = element.querySelectorAll && element.querySelectorAll('video, audio');
                        if (mediaElements && mediaElements.length > 0) {
                            hasNewMedia = true;
                            mediaElements.forEach(media => {
                                media.addEventListener('play', debouncedUpdateMediaState);
                                media.addEventListener('playing', debouncedUpdateMediaState);
                                media.addEventListener('pause', debouncedUpdateMediaState);
                                media.addEventListener('ended', debouncedUpdateMediaState);
                                media.addEventListener('volumechange', debouncedUpdateMediaState);
                                media.addEventListener('loadeddata', debouncedUpdateMediaState);
                                media.addEventListener('timeupdate', debouncedUpdateMediaState);
                                media.addEventListener('seeking', debouncedUpdateMediaState);
                                media.addEventListener('seeked', debouncedUpdateMediaState);
                                media.addEventListener('ratechange', debouncedUpdateMediaState);
                            });
                        }
                    }
                }
            }
            if (hasNewMedia) {
                setTimeout(updateMediaState, 200);
            }
        });

        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        } else {
            document.addEventListener('DOMContentLoaded', function onReady() {
                document.removeEventListener('DOMContentLoaded', onReady);
                observer.observe(document.body, { childList: true, subtree: true });
            });
        }

        // Fallback periodic check
        setInterval(updateMediaState, 3000);

        // Ensure we clear state when this frame is being unloaded
        const sendSilence = () => {
            try { window.webkit.messageHandlers.mediaState.postMessage({ frameId: FRAME_ID, isPlaying: false }); } catch (e) {}
        };
        window.addEventListener('pagehide', sendSilence);
        window.addEventListener('unload', sendSilence);
    })();
    """

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
        } else if message.name == "mediaState" {
            // Handle media play/pause state changes (aggregated across frames)
            if let payload = message.body as? [String: Any],
               let frameId = payload["frameId"] as? String,
               let isPlaying = payload["isPlaying"] as? Bool
            {
                if isPlaying {
                    playingFrameIds.insert(frameId)
                } else {
                    playingFrameIds.remove(frameId)
                }
                let aggregated = !playingFrameIds.isEmpty
                DispatchQueue.main.async {
                    guard let tab = self.tab else { return }
                    if tab.isPlayingMedia != aggregated {
                        tab.isPlayingMedia = aggregated
                    }
                }
            } else if let isPlaying = message.body as? Bool {
                // Backward compatibility with older script that sent a bare Bool
                DispatchQueue.main.async {
                    guard let tab = self.tab else { return }
                    tab.isPlayingMedia = isPlaying
                }
            }
        }
    }

    func defaultWKConfig() -> WKWebViewConfiguration {
        // Configure WebView for performance
        let configuration = WKWebViewConfiguration()
        let userAgent =
            "Mozilla/5.0 (Macintosh; arm64 Mac OS X 14_5) AppleWebKit/616.1.1 (KHTML, like Gecko) Version/18.5 Safari/616.1.1 Ora/1.0"
//        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)
//        Chrome/133.0.0.0 Safari/537.36"
        configuration.applicationNameForUserAgent = userAgent

        // Enable JavaScript
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled") // This is key
        configuration.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        configuration.preferences.setValue(true, forKey: "javaScriptEnabled")
        configuration.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
        configuration.websiteDataStore = WKWebsiteDataStore.default()

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

        // Set up caching
        let websiteDataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = websiteDataStore

        // GPU acceleration settings
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // injecting listeners
        let contentController = WKUserContentController()
        contentController.add(self, name: "listener")
        contentController.add(self, name: "linkHover")
        contentController.add(self, name: "mediaState")

        // Inject media detection JavaScript
        let mediaScript = WKUserScript(
            source: TabScriptHandler.mediaDetectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(mediaScript)

        configuration.userContentController = contentController

        return configuration
    }

    deinit {
        // Optional cleanup
        logger.debug("TabScriptHandler deinitialized")
    }
}
