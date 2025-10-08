import AppKit
import Foundation
import os.log
import SwiftUI
@preconcurrency import WebKit

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "WebViewNavigationDelegate")

// JavaScript for monitoring URL, title, and favicon changes
let navigationScript = """
(function () {
    let lastHref = location.href;
    let lastTitle = document.title;
    let faviconURL = null;

    function findFavicon(callback) {
        const links = document.getElementsByTagName('link');
        for (let i = 0; i < links.length; i++) {
            const rel = links[i].getAttribute('rel');
            if (rel && rel.toLowerCase().includes('icon')) {
                const href = links[i].getAttribute('href');
                if (href) return callback(new URL(href, document.baseURI).href);
            }
        }
        callback(`https://www.google.com/s2/favicons?domain=${location.hostname}`);
    }

    function notifyChange(force = false) {
        if (force || location.href !== lastHref || document.title !== lastTitle) {
            lastHref = location.href;
            lastTitle = document.title;
            window.webkit.messageHandlers.listener.postMessage(
                JSON.stringify({ href: lastHref, title: lastTitle, favicon: faviconURL })
            );
        }
    }

    const titleObserver = new MutationObserver(() => notifyChange());
    const titleElement = document.querySelector('title');
    if (titleElement) titleObserver.observe(titleElement, { childList: true });

    setInterval(() => notifyChange(), 500);
    window.addEventListener('popstate', () => notifyChange(true));
    findFavicon((icon) => { faviconURL = icon; notifyChange(true); });

    // Hover link detection: post hovered link URL via linkHover handler
    function postHover(url) {
        try { window.webkit.messageHandlers.linkHover.postMessage(url || ""); } catch (e) {}
    }
    let hoverTimer = null;
    function onMouseOver(e) {
        const a = e.target.closest && e.target.closest('a[href]');
        const href = a ? a.href : '';
        postHover(href);
    }
    function onMouseOut(e) {
        const related = e.relatedTarget;
        if (!related || !e.currentTarget.contains(related)) {
            postHover("");
        }
    }
    document.addEventListener('mouseover', onMouseOver, true);
    document.addEventListener('mouseout', onMouseOut, true);
})();
// Media detection & control bridge
(function () {
    if (window.__oraMediaInstalled) return; // prevent double-inject
    window.__oraMediaInstalled = true;

    function post(payload) {
        try {
            window.webkit.messageHandlers.mediaEvent.postMessage(JSON.stringify(payload));
        } catch (e) {}
    }

    function findNextButton() {
        const selectors = [
            '.ytp-next-button',
            'button[aria-label*="Next" i]',
            'button[title*="Next" i]',
            '[data-testid="control-button-skip-forward"]'
        ];
        for (const s of selectors) {
            const el = document.querySelector(s);
            if (el) return el;
        }
        return null;
    }
    function findPrevButton() {
        const selectors = [
            '.ytp-prev-button',
            'button[aria-label*="Previous" i]',
            'button[title*="Previous" i]',
            '[data-testid="control-button-skip-backward"]'
        ];
        for (const s of selectors) {
            const el = document.querySelector(s);
            if (el) return el;
        }
        return null;
    }

    function caps() {
        post(
            {
                type: 'caps',
                hasNext: !!findNextButton(),
                hasPrevious: !!findPrevButton()
            }
        );
    }

    const stateFrom = (el) => ({
        type: 'state',
        state: el && !el.paused ? 'playing' : 'paused',
        volume: el ? (el.muted ? 0 : el.volume) : undefined,
        title: document.title
    });

    // Enhanced title change monitoring for media sessions
    let lastMediaTitle = document.title;
    function checkTitleChange() {
        if (document.title !== lastMediaTitle) {
            lastMediaTitle = document.title;
            // If any media is currently playing, send a title update
            const activeMedia = document.querySelector('video:not([paused]), audio:not([paused])');
            if (activeMedia) {
                post({ type: 'titleChange', title: document.title });
            }
        }
    }

    function attach(el) {
        if (!el || el.__oraAttached) return;
        el.__oraAttached = true;
        const update = () => post(stateFrom(el));
        el.addEventListener('play', update);
        el.addEventListener('pause', update);
        el.addEventListener('ended', () => post({ type: 'ended' }));
        el.addEventListener('volumechange', () =>
            post({ type: 'volume', volume: el.muted ? 0 : el.volume })
        );
        // If already playing, announce
        if (!el.paused) update();
    }

    function scan() {
        document.querySelectorAll('video, audio').forEach(attach);
        caps();
    }

    const mo = new MutationObserver(scan);
    mo.observe(document.documentElement, { childList: true, subtree: true });
    scan();

    // Set up periodic title checking for active media
    setInterval(checkTitleChange, 1000);

    window.__oraMedia = {
        active: null,
        _pick() {
            // Prefer any not-paused media, otherwise first element
            const els = Array.from(document.querySelectorAll('video, audio'));
            const playing = els.find(e => !e.paused);
            this.active = playing || els[0] || null;
            return this.active;
        },
        play() {
            try {
                (this._pick()||{}).play(); return true;
            } catch(e) { return false; }
        },
        pause() {
            try {
                (this._pick()||{}).pause(); return true;
            } catch(e) { return false; }
        },
        toggle() {
            const el = this._pick();
            if (!el) return false;
            if (el.paused) {
                el.play();
            } else {
                el.pause();
            }
            return true;
        },
        setVolume(v) {
            const el = this._pick();
            if (!el) return false;
            el.muted = false;
            el.volume = Math.max(0, Math.min(1, v));
            post({ type: 'volume', volume: el.volume });
            return true;
        },
        deltaVolume(d) {
            const el = this._pick();
            if (!el) return false;
            el.muted = false;
            el.volume = Math.max(0, Math.min(1, (el.volume||0) + d));
            post({ type: 'volume', volume: el.volume });
            return true;
        },
        next() {
            const el = findNextButton();
            if (el) {
                el.click(); caps(); return true;
            }
            return false;
        },
        previous() {
            const el = findPrevButton();
            if (el) {
                el.click(); caps(); return true;
            }
            return false;
        },
        title() {
            return document.title;
        }
    };

    post({ type: 'ready', title: document.title });
})();
"""

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    var onProgressChange: ((Double) -> Void)?
    var onChange: ((String?, URL?) -> Void)?
    var onStart: (() -> Void)?
    weak var tab: Tab?
    private var downloadDelegates: [UUID: DownloadDelegate] = [:]
    private var isDownloadNavigation = false
    private var originalURL: URL?

    // MARK: - Handle cmd+click to open in new tab

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Check if command key is pressed (cmd+click)
        logger
            .debug(
                """
                Navigation action - modifier flags: \(navigationAction.modifierFlags.rawValue), \
                contains command: \(navigationAction.modifierFlags.contains(.command))
                """
            )
        if navigationAction.modifierFlags.contains(.command),
           let url = navigationAction.request.url,
           let tab = self.tab,
           let tabManager = tab.tabManager,
           let historyManager = tab.historyManager,
           let downloadManager = tab.downloadManager
        {
            // Open link in new tab
            DispatchQueue.main.async {
                tabManager.openTab(
                    url: url,
                    historyManager: historyManager,
                    downloadManager: downloadManager,
                    isPrivate: tab.isPrivate
                )
            }

            // Cancel the current navigation
            decisionHandler(.cancel)
            return
        }

        // Allow normal navigation
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if !isDownloadNavigation {
            // Store original URL before navigation
            originalURL = tab?.url
            onLoadingChange?(true)
            onProgressChange?(10.0)
            onURLChange?(webView.url)
            onStart?()
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if !isDownloadNavigation {
            onTitleChange?(webView.title)
            onProgressChange?(webView.estimatedProgress * 100.0)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !isDownloadNavigation {
            onLoadingChange?(false)
            onTitleChange?(webView.title)
            onURLChange?(webView.url)
            onChange?(webView.title, webView.url)
            onProgressChange?(webView.estimatedProgress * 100.0)
            webView.evaluateJavaScript(navigationScript, completionHandler: nil)
            injectDownloadScriptIfNeeded(webView)
            takeSnapshotAfterLoad(webView)
            originalURL = nil // Clear stored URL after successful navigation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.onProgressChange?(0.0)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if !isDownloadNavigation {
            onLoadingChange?(false)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }

            tab?.setNavigationError(error, for: webView.url)
        }
        originalURL = nil // Clear stored URL on navigation failure
        onProgressChange?(100.0)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !isDownloadNavigation {
            onLoadingChange?(false)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }

            tab?.setNavigationError(error, for: webView.url)
            onProgressChange?(100.0)
        }
        originalURL = nil // Clear stored URL on navigation failure
    }

    @available(macOS 11.3, *)
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            isDownloadNavigation = false
            originalURL = nil // Clear stored URL for normal navigation
            decisionHandler(.allow)
        } else {
            isDownloadNavigation = true // Mark as download to suppress navigation callbacks

            // Revert URL bar back to original URL since this is a download
            if let originalURL {
                onURLChange?(originalURL)
            }

            // Set loading to false since navigation won't complete normally for downloads
            onLoadingChange?(false)

            decisionHandler(.download)
        }
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        handleDownload(download, from: navigationResponse.response.url)
    }

    @available(macOS 11.3, *)
    private func handleDownload(_ download: WKDownload, from url: URL?) {
        guard let downloadManager = tab?.downloadManager, let originalURL = url else { return }
        let downloadDelegate = DownloadDelegate(
            downloadManager: downloadManager,
            originalURL: originalURL,
            wkDownload: download
        )
        download.delegate = downloadDelegate
        downloadDelegates[downloadDelegate.id] = downloadDelegate
        downloadDelegate.onCompletion = { [weak self] id in
            self?.downloadDelegates.removeValue(forKey: id)
            self?.isDownloadNavigation = false // Reset after download completes
            self?.originalURL = nil // Clear stored original URL
        }
    }

    func takeSnapshotAfterLoad(_ webView: WKWebView) {
        guard !webView.isLoading, webView.bounds.width > 0 else { return }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: 24)

        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self, let image, error == nil else { return }

            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let color = self.extractDominantColor(from: cgImage)
                DispatchQueue.main.async {
                    self.tab?.updateBackgroundColor(Color(nsColor: color ?? .black))
                    self.tab?.colorUpdated = true
                }
            }
        }
    }

    private func injectDownloadScriptIfNeeded(_ webView: WKWebView) {
        guard let url = webView.url, url.host?.contains("mozilla.org") == true else { return }

        // Inject script to add a fixed floating download button if .xpi links are found
        let downloadScript = """
        (function() {
            const xpiLinks = document.querySelectorAll('a[href*=".xpi"]');
            if (xpiLinks.length > 0 && !document.querySelector('.ora-floating-download-btn')) {
                const button = document.createElement('button');
                button.innerText = 'Download to Ora!';
                button.className = 'ora-floating-download-btn';
                button.style.position = 'fixed';
                button.style.top = '20px';
                button.style.right = '20px';
                button.style.zIndex = '10000';
                button.style.padding = '12px 20px';
                button.style.background = 'linear-gradient(45deg, #ff6b35, #f7931e, #ff4757)';
                button.style.color = 'white';
                button.style.border = '3px solid #fff';
                button.style.borderRadius = '25px';
                button.style.cursor = 'pointer';
                button.style.boxShadow = '0 4px 15px rgba(255, 107, 53, 0.4)';
                button.style.fontWeight = 'bold';
                button.style.fontSize = '14px';
                button.style.textTransform = 'uppercase';
                button.style.letterSpacing = '1px';
                button.style.transition = 'all 0.3s ease';
                button.onmouseover = function() { button.style.transform = 'scale(1.05)'; button.style.boxShadow = '0 6px 20px rgba(255, 107, 53, 0.6)'; };
                button.onmouseout = function() { button.style.transform = 'scale(1)'; button.style.boxShadow = '0 4px 15px rgba(255, 107, 53, 0.4)'; };
                button.onclick = function(e) {
                    const link = xpiLinks[0]; // Download the first .xpi link
                    window.webkit.messageHandlers.downloadExtension.postMessage({url: link.href});
                };
                document.body.appendChild(button);
            }
        })();
        """
        webView.evaluateJavaScript(downloadScript, completionHandler: nil)
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
        let tempFileURL = tempDir.appendingPathComponent("downloaded_extension.xpi")
        do {
            try data.write(to: tempFileURL)
        } catch {
            logger.error("Failed to save temp file: \(error)")
            return
        }

        // Extract
        let extensionsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("extensions")
        if !FileManager.default.fileExists(atPath: extensionsDir.path) {
            try? FileManager.default.createDirectory(at: extensionsDir, withIntermediateDirectories: true)
        }

        // Create subfolder named after the file
        let fileName = url.deletingPathExtension().lastPathComponent
        let extractDir = extensionsDir.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: extractDir.path) {
            try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        }

        // Extract using unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempFileURL.path, "-d", extractDir.path]
        do {
            try process.run()
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
        } catch {
            logger.error("Failed to extract: \(error)")
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    private func extractDominantColor(from cgImage: CGImage) -> NSColor? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = context.data else { return nil }

        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let red = CGFloat(pixels[0]) / 255.0
        let green = CGFloat(pixels[1]) / 255.0
        let blue = CGFloat(pixels[2]) / 255.0
        let alpha = CGFloat(pixels[3]) / 255.0

        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

@available(macOS 11.3, *)
class DownloadDelegate: NSObject, WKDownloadDelegate {
    let id = UUID()
    let downloadManager: DownloadManager
    var originalURL: URL
    let wkDownload: WKDownload
    var download: Download?
    var onCompletion: ((UUID) -> Void)?
    private var progressTimer: Timer?

    init(downloadManager: DownloadManager, originalURL: URL, wkDownload: WKDownload) {
        self.downloadManager = downloadManager
        self.originalURL = originalURL
        self.wkDownload = wkDownload
        super.init()
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsDir = downloadManager.getDownloadsDirectory()
        let destinationURL = downloadsDir.appendingPathComponent(suggestedFilename)
        let finalURL = downloadManager.createUniqueFilename(for: destinationURL)

        Task { @MainActor in
            let expectedSize = (response as? HTTPURLResponse)?.expectedContentLength ?? 0
            self.download = downloadManager.startDownload(
                from: download,
                originalURL: originalURL,
                suggestedFilename: suggestedFilename,
                expectedSize: expectedSize
            )

            // Start timer to monitor WKDownload progress
            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let download = self.download else { return }
                let completedBytes = self.wkDownload.progress.completedUnitCount
                let totalBytes = self.wkDownload.progress.totalUnitCount > 0 ? self.wkDownload.progress
                    .totalUnitCount : expectedSize
                Task { @MainActor in
                    self.downloadManager.updateDownloadProgress(
                        download,
                        downloadedBytes: completedBytes,
                        totalBytes: totalBytes
                    )
                }
            }
        }
        completionHandler(finalURL)
    }

    func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let newURL = newRequest.url {
            self.originalURL = newURL
            if let download = self.download {
                download.originalURL = newURL
                download.originalURLString = newURL.absoluteString
                try? downloadManager.modelContext.save()
            }
        }
        decisionHandler(.allow)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let download = self.download else { return }
        let destinationURL = downloadManager.getDownloadsDirectory().appendingPathComponent(download.fileName)
        Task { @MainActor in
            downloadManager.completeDownload(download, destinationURL: destinationURL)
        }
        cleanup()
        onCompletion?(id)
    }

    func download(_ download: WKDownload, didFailWithError error: Error) {
        guard let download = self.download else { return }
        Task { @MainActor in
            downloadManager.failDownload(download, error: error.localizedDescription)
        }
        cleanup()
        onCompletion?(id)
    }

    private func cleanup() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
