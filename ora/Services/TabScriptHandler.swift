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
    private var playingFrameIds = Set<String>() // audible
    private var activeFrameIds = Set<String>()  // playing regardless of mute

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

        // Track and control WebAudio contexts (AudioContext / webkitAudioContext)
        window.__oraAudioContexts = window.__oraAudioContexts || new Set();
        (function patchAudioContext() {
            if (window.__oraPatchedAudioCtx) return;
            const Original = window.AudioContext || window.webkitAudioContext;
            if (!Original) return;
            function Wrapped(...args) {
                const ctx = new Original(...args);
                try {
                    window.__oraAudioContexts.add(ctx);
                    if (window.__oraForcedMute && ctx.state !== 'suspended') {
                        ctx.suspend().catch(() => {});
                    }
                } catch (e) {}
                return ctx;
            }
            Wrapped.prototype = Original.prototype;
            try {
                if (window.AudioContext) window.AudioContext = Wrapped;
                if (window.webkitAudioContext) window.webkitAudioContext = Wrapped;
                window.__oraPatchedAudioCtx = true;
            } catch (e) {}
        })();
        function enforceAudioContextMute() {
            try {
                window.__oraAudioContexts && window.__oraAudioContexts.forEach(ctx => {
                    try {
                        if (window.__oraForcedMute) {
                            if (ctx.state !== 'suspended') { ctx.suspend().catch(() => {}); }
                        } else {
                            if (ctx.state === 'suspended') { ctx.resume().catch(() => {}); }
                        }
                    } catch (e) {}
                });
            } catch (e) {}
        }

        let lastMediaState = false;
        let lastActiveState = false;
        let debounceTimer = null;
        let seekGraceMs = 5000; // 5s threshold to avoid flicker during short seeks
        let seekGraceUntil = 0;

        // Forced mute control without changing page-visible mute state
        // We avoid toggling HTMLMediaElement.muted to prevent UI desync in players (e.g., YouTube).
        window.__oraForcedMute = window.__oraForcedMute || false;
        function applyForcedMuteTo(el) {
            try {
                if (window.__oraForcedMute) {
                    if (el.__oraPrevVolume === undefined || el.__oraPrevVolume === null) {
                        el.__oraPrevVolume = el.volume;
                    }
                    if (el.volume > 0) {
                        el.volume = 0;
                    }
                } else {
                    if (el.__oraPrevVolume !== undefined && el.__oraPrevVolume !== null) {
                        el.volume = el.__oraPrevVolume;
                        el.__oraPrevVolume = null;
                        try { delete el.__oraPrevVolume; } catch (e) {}
                    }
                }
            } catch (e) {}
        }
        function applyForcedMuteAll() {
            const mediaElements = document.querySelectorAll('video, audio');
            mediaElements.forEach(applyForcedMuteTo);
        }
        // Background enforcement loop while forced mute is enabled
        window.__oraMuteInterval && clearInterval(window.__oraMuteInterval);
        window.__oraMuteInterval = null;

        function setForcedMute(flag) {
            try {
                window.__oraForcedMute = !!flag;
                applyForcedMuteAll();
                enforceAudioContextMute();
                if (window.__oraForcedMute && !window.__oraMuteInterval) {
                    window.__oraMuteInterval = setInterval(function(){
                        applyForcedMuteAll();
                        enforceAudioContextMute();
                    }, 250);
                } else if (!window.__oraForcedMute && window.__oraMuteInterval) {
                    clearInterval(window.__oraMuteInterval);
                    window.__oraMuteInterval = null;
                }
                debouncedUpdateMediaState();
            } catch (e) {}
        }

        function broadcastForcedMute(flag) {
            try { window.postMessage({ __ORA_MUTE_TOGGLE: !!flag }, "*"); } catch (e) {}
            try {
                const iframes = document.querySelectorAll('iframe');
                iframes.forEach(f => { try { f.contentWindow && f.contentWindow.postMessage({ __ORA_MUTE_TOGGLE: !!flag }, "*"); } catch (e) {} });
            } catch (e) {}
            try { if (window.top && window.top !== window) { window.top.postMessage({ __ORA_MUTE_TOGGLE: !!flag }, "*"); } } catch (e) {}
        }

        window.addEventListener('message', function(evt) {
            try {
                const data = evt && evt.data;
                if (data && Object.prototype.hasOwnProperty.call(data, '__ORA_MUTE_TOGGLE')) {
                    setForcedMute(!!data.__ORA_MUTE_TOGGLE);
                }
            } catch (e) {}
        }, false);

        window.__oraSetForcedMute = function(flag) {
            setForcedMute(flag);
            broadcastForcedMute(flag);
        }

        function isElementAudible(el) {
            // Consider readyState to filter out elements that aren't actually playing yet
            const hasData = (typeof el.readyState === 'number') ? (el.readyState >= 2) : true;
            return !el.paused && el.currentTime > 0 && !el.muted && el.volume > 0 && hasData && !el.seeking;
        }
        function isElementActive(el) {
            const hasData = (typeof el.readyState === 'number') ? (el.readyState >= 2) : true;
            return !el.paused && el.currentTime > 0 && hasData && !el.seeking;
        }

        function updateMediaState() {
            const now = Date.now();
            const mediaElements = document.querySelectorAll('video, audio');
            let rawPlaying = false; // audible
            let rawActive = false;  // playing ignoring mute/volume

            for (const media of mediaElements) {
                if (isElementActive(media)) { rawActive = true; }
                if (isElementAudible(media)) { rawPlaying = true; }
                if (rawPlaying && rawActive) { break; }
            }

            // Consider WebAudio contexts as active if any are running
            try {
                if (window.__oraAudioContexts) {
                    window.__oraAudioContexts.forEach(ctx => { if (ctx.state === 'running') { rawActive = true; } });
                }
            } catch (e) {}

            // Apply grace to suppress brief dropouts due to short seeks
            let isPlaying = rawPlaying;
            let isActive = rawActive;
            if (now < seekGraceUntil) {
                if (lastMediaState && !rawPlaying) { isPlaying = true; }
                if (lastActiveState && !rawActive) { isActive = true; }
            }

            if (isPlaying !== lastMediaState || isActive !== lastActiveState) {
                lastMediaState = isPlaying;
                lastActiveState = isActive;
                try {
                    window.webkit.messageHandlers.mediaState.postMessage({ frameId: FRAME_ID, isPlaying: isPlaying, isActive: isActive });
                } catch (e) { /* no-op */ }
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
                media.addEventListener('loadedmetadata', debouncedUpdateMediaState);
                media.addEventListener('loadstart', debouncedUpdateMediaState);
                media.addEventListener('canplay', debouncedUpdateMediaState);
                media.addEventListener('canplaythrough', debouncedUpdateMediaState);
                media.addEventListener('timeupdate', debouncedUpdateMediaState);
                media.addEventListener('seeking', () => { seekGraceUntil = Date.now() + seekGraceMs; debouncedUpdateMediaState(); });
                media.addEventListener('seeked', debouncedUpdateMediaState);
                media.addEventListener('ratechange', debouncedUpdateMediaState);
                // Enforce forced mute on relevant transitions
                media.addEventListener('play', () => applyForcedMuteTo(media));
                media.addEventListener('loadeddata', () => applyForcedMuteTo(media));
                media.addEventListener('loadedmetadata', () => applyForcedMuteTo(media));
                media.addEventListener('loadstart', () => applyForcedMuteTo(media));
                media.addEventListener('canplay', () => applyForcedMuteTo(media));
                media.addEventListener('canplaythrough', () => applyForcedMuteTo(media));
                media.addEventListener('volumechange', () => applyForcedMuteTo(media));
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
                            element.addEventListener('loadedmetadata', debouncedUpdateMediaState);
                            element.addEventListener('loadstart', debouncedUpdateMediaState);
                            element.addEventListener('canplay', debouncedUpdateMediaState);
                            element.addEventListener('canplaythrough', debouncedUpdateMediaState);
                            element.addEventListener('timeupdate', debouncedUpdateMediaState);
                            element.addEventListener('seeking', () => { seekGraceUntil = Date.now() + seekGraceMs; debouncedUpdateMediaState(); });
                            element.addEventListener('seeked', debouncedUpdateMediaState);
                            element.addEventListener('ratechange', debouncedUpdateMediaState);
                            applyForcedMuteTo(element);
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
                                media.addEventListener('seeking', () => { seekGraceUntil = Date.now() + seekGraceMs; debouncedUpdateMediaState(); });
                                media.addEventListener('seeked', debouncedUpdateMediaState);
                                media.addEventListener('ratechange', debouncedUpdateMediaState);
                                applyForcedMuteTo(media);
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
            try { window.webkit.messageHandlers.mediaState.postMessage({ frameId: FRAME_ID, isPlaying: false, isActive: false }); } catch (e) {}
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
                let isActive = (payload["isActive"] as? Bool) ?? isPlaying
                if isPlaying { playingFrameIds.insert(frameId) } else { playingFrameIds.remove(frameId) }
                if isActive { activeFrameIds.insert(frameId) } else { activeFrameIds.remove(frameId) }
                let aggregatedPlaying = !playingFrameIds.isEmpty
                let aggregatedActive = !activeFrameIds.isEmpty
                DispatchQueue.main.async {
                    guard let tab = self.tab else { return }
                    if tab.isMediaActive != aggregatedActive { tab.isMediaActive = aggregatedActive }
                    if tab.isPlayingMedia != aggregatedPlaying { tab.isPlayingMedia = aggregatedPlaying }
                }
            } else if let isPlaying = message.body as? Bool {
                // Backward compatibility with older script that sent a bare Bool
                DispatchQueue.main.async {
                    guard let tab = self.tab else { return }
                    tab.isPlayingMedia = isPlaying
                    tab.isMediaActive = isPlaying
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
