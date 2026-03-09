import AppKit
import Foundation
@preconcurrency import WebKit

final class WebKitBrowserProfile: BrowserEngineProfile {
    let dataStore: WKWebsiteDataStore

    init(identifier: UUID, isPrivate: Bool) {
        if isPrivate {
            self.dataStore = WKWebsiteDataStore.nonPersistent()
        } else {
            self.dataStore = WKWebsiteDataStore(forIdentifier: identifier)
        }
        super.init(identifier: identifier, isPrivate: isPrivate, engineKind: .webKit)
    }

    override func clearData(
        ofTypes types: Set<BrowserWebsiteDataType>,
        forHost host: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        let mappedTypes = mapWebsiteDataTypes(types)
        guard let host, !host.isEmpty else {
            dataStore.removeData(ofTypes: mappedTypes, modifiedSince: .distantPast) {
                completion?()
            }
            return
        }

        dataStore.fetchDataRecords(ofTypes: mappedTypes) { records in
            let targetRecords = records.filter { $0.displayName.contains(host) }
            guard !targetRecords.isEmpty else {
                completion?()
                return
            }

            self.dataStore.removeData(ofTypes: mappedTypes, for: targetRecords) {
                completion?()
            }
        }
    }

    private func mapWebsiteDataTypes(_ types: Set<BrowserWebsiteDataType>) -> Set<String> {
        if types.contains(.all) {
            return WKWebsiteDataStore.allWebsiteDataTypes()
        }

        var mapped: Set<String> = []
        if types.contains(.cookies) {
            mapped.insert(WKWebsiteDataTypeCookies)
        }
        if types.contains(.cache) {
            mapped.formUnion(WKWebsiteDataStore.allWebsiteDataTypes())
        }
        return mapped
    }
}

final class WebKitBrowserDownloadTask: BrowserDownloadTask, WKDownloadDelegate {
    private let download: WKDownload

    init(download: WKDownload, originalURL: URL) {
        self.download = download
        super.init(originalURL: originalURL)
        self.download.delegate = self
    }

    override var progress: Progress {
        download.progress
    }

    override func cancel() {
        download.cancel()
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        if let onDestinationRequest {
            onDestinationRequest(response, suggestedFilename, completionHandler)
        } else {
            completionHandler(nil)
        }
    }

    func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void
    ) {
        if let url = newRequest.url {
            originalURL = url
            onRedirect?(url)
        }
        decisionHandler(.allow)
    }

    func downloadDidFinish(_ download: WKDownload) {
        onFinish?()
    }

    func download(_ download: WKDownload, didFailWithError error: Error) {
        onFail?(error)
    }
}

final class WebKitBrowserPage: BrowserPage, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let webView: WKWebView
    private let messageNames: [String]
    private var originalURL: URL?
    private var lastCommittedURL: URL?
    private var isDownloadNavigation = false

    init(
        profile: WebKitBrowserProfile,
        configuration: BrowserPageConfiguration,
        delegate: BrowserPageDelegate?
    ) {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.applicationNameForUserAgent = configuration.userAgent
        webConfiguration.websiteDataStore = profile.dataStore
        webConfiguration.allowsAirPlayForMediaPlayback = configuration.allowsAirPlayForMediaPlayback
        webConfiguration.preferences.setValue(
            configuration.allowsInspectableDebugging,
            forKey: "developerExtrasEnabled"
        )
        webConfiguration.preferences.setValue(
            configuration.allowsPictureInPicture,
            forKey: "allowsPictureInPictureMediaPlayback"
        )
        webConfiguration.preferences.setValue(configuration.allowsJavaScript, forKey: "javaScriptEnabled")
        webConfiguration.preferences.setValue(
            configuration.allowsJavaScriptWindowsAutomatically,
            forKey: "javaScriptCanOpenWindowsAutomatically"
        )
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically =
            configuration.allowsJavaScriptWindowsAutomatically
        webConfiguration.preferences.isElementFullscreenEnabled = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback =
            configuration.mediaPlaybackRequiresUserAction ? .all : []

        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = configuration.allowsJavaScript
        webConfiguration.defaultWebpagePreferences = webpagePreferences

        let contentController = WKUserContentController()
        webConfiguration.userContentController = contentController
        self.messageNames = configuration.scriptMessageNames
        self.webView = WKWebView(frame: .zero, configuration: webConfiguration)

        super.init(engineKind: .webKit, delegate: delegate)

        for messageName in configuration.scriptMessageNames {
            contentController.add(self, name: messageName)
        }
        for script in configuration.userScripts {
            let userScript = WKUserScript(
                source: script.source,
                injectionTime: mapInjectionTime(script.injectionTime),
                forMainFrameOnly: script.forMainFrameOnly
            )
            contentController.addUserScript(userScript)
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = configuration.allowsBackForwardNavigationGestures
        webView.wantsLayer = true
        webView.isInspectable = configuration.allowsInspectableDebugging
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }
    }

    override var contentView: NSView {
        webView
    }

    override var window: NSWindow? {
        webView.window
    }

    override var currentURL: URL? {
        webView.url
    }

    override var title: String? {
        webView.title
    }

    override var canGoBack: Bool {
        webView.canGoBack
    }

    override var canGoForward: Bool {
        webView.canGoForward
    }

    override var isLoading: Bool {
        webView.isLoading
    }

    override var estimatedProgress: Double {
        webView.estimatedProgress
    }

    override func load(_ request: URLRequest) {
        webView.load(request)
    }

    override func reload() {
        webView.reload()
    }

    override func goBack() {
        webView.goBack()
    }

    override func goForward() {
        webView.goForward()
    }

    override func stopLoading() {
        webView.stopLoading()
    }

    override func evaluateJavaScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }

    override func takeSnapshot(
        configuration: BrowserSnapshotConfiguration,
        completion: @escaping (NSImage?, Error?) -> Void
    ) {
        let snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.afterScreenUpdates = configuration.afterScreenUpdates
        if let rect = configuration.rect {
            snapshotConfiguration.rect = rect
        }
        webView.takeSnapshot(with: snapshotConfiguration, completionHandler: completion)
    }

    override func closeMediaPresentations(completion: @escaping () -> Void) {
        webView.closeAllMediaPresentations(completionHandler: completion)
    }

    override func teardown() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        for messageName in messageNames {
            controller.removeScriptMessageHandler(forName: messageName)
        }
        webView.removeFromSuperview()
    }

    private func emitNavigationEvent(
        phase: BrowserNavigationPhase,
        url: URL?,
        title: String?,
        progress: Double,
        isLoading: Bool
    ) {
        delegate?.browserPage(
            self,
            didUpdateNavigation: BrowserNavigationEvent(
                phase: phase,
                url: url,
                title: title,
                progress: progress,
                isLoading: isLoading
            )
        )
    }

    private func handleCancelledNavigationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func mapInjectionTime(_ injectionTime: BrowserUserScriptInjectionTime) -> WKUserScriptInjectionTime {
        switch injectionTime {
        case .atDocumentStart:
            return .atDocumentStart
        case .atDocumentEnd:
            return .atDocumentEnd
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.browserPage(
            self,
            didReceiveScriptMessage: BrowserScriptMessage(name: message.name, body: message.body)
        )
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let action = BrowserNavigationAction(
            request: navigationAction.request,
            modifierFlags: navigationAction.modifierFlags
        )

        switch delegate?.browserPage(self, decidePolicyFor: action) ?? .allow {
        case .allow:
            decisionHandler(.allow)
        case .cancel:
            decisionHandler(.cancel)
        case .openInNewTab:
            if let url = navigationAction.request.url {
                delegate?.browserPage(self, didRequestOpenInNewTab: url)
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if !isDownloadNavigation {
            originalURL = lastCommittedURL
            emitNavigationEvent(
                phase: .started,
                url: webView.url,
                title: webView.title,
                progress: 10.0,
                isLoading: true
            )
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if !isDownloadNavigation {
            lastCommittedURL = webView.url
            emitNavigationEvent(
                phase: .committed,
                url: webView.url,
                title: webView.title,
                progress: webView.estimatedProgress * 100.0,
                isLoading: true
            )
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !isDownloadNavigation {
            lastCommittedURL = webView.url
            emitNavigationEvent(
                phase: .finished,
                url: webView.url,
                title: webView.title,
                progress: webView.estimatedProgress * 100.0,
                isLoading: false
            )
            originalURL = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !isDownloadNavigation else {
            originalURL = nil
            return
        }

        emitNavigationEvent(
            phase: .finished,
            url: webView.url,
            title: webView.title,
            progress: 100.0,
            isLoading: false
        )

        if !handleCancelledNavigationError(error) {
            delegate?.browserPage(self, didFailNavigationWith: error, failingURL: webView.url)
        }
        originalURL = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !isDownloadNavigation else {
            originalURL = nil
            return
        }

        emitNavigationEvent(
            phase: .finished,
            url: webView.url,
            title: webView.title,
            progress: 100.0,
            isLoading: false
        )

        if handleCancelledNavigationError(error) {
            return
        }

        let nsError = error as NSError
        let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? webView.url
        delegate?.browserPage(self, didFailNavigationWith: error, failingURL: failingURL)
        originalURL = nil
    }

    @available(macOS 11.3, *)
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            isDownloadNavigation = false
            originalURL = nil
            decisionHandler(.allow)
            return
        }

        isDownloadNavigation = true
        emitNavigationEvent(
            phase: .finished,
            url: originalURL,
            title: webView.title,
            progress: 0,
            isLoading: false
        )
        decisionHandler(.download)
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        guard let downloadURL = navigationResponse.response.url else { return }
        let task = WebKitBrowserDownloadTask(download: download, originalURL: downloadURL)
        delegate?.browserPage(self, didStartDownload: task)
        isDownloadNavigation = false
        originalURL = nil
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let pageURL = URL(string: "\(origin.protocol)://\(origin.host):\(origin.port)")
        delegate?.browserPage(self, requestPermission: .mediaCapture, origin: pageURL) { decision in
            decisionHandler(decision == .grant ? .grant : .deny)
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        delegate?.browserPage(
            self,
            runOpenPanelWith: BrowserOpenPanelOptions(
                allowsDirectories: parameters.allowsDirectories,
                allowsMultipleSelection: parameters.allowsMultipleSelection
            ),
            completion: completionHandler
        )
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            delegate?.browserPage(self, didRequestOpenInNewTab: url)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        delegate?.browserPage(self, runJavaScriptAlert: message)
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        delegate?.browserPage(self, runJavaScriptConfirm: message, completion: completionHandler)
    }
}

final class WebKitBrowserEngine: BrowserEngine {
    init() {
        super.init(kind: .webKit)
    }

    override func makeProfile(identifier: UUID, isPrivate: Bool) -> BrowserEngineProfile {
        WebKitBrowserProfile(identifier: identifier, isPrivate: isPrivate)
    }

    override func makePage(
        profile: BrowserEngineProfile,
        configuration: BrowserPageConfiguration,
        delegate: BrowserPageDelegate?
    ) -> BrowserPage {
        guard let webKitProfile = profile as? WebKitBrowserProfile else {
            preconditionFailure("WebKitBrowserEngine requires a WebKitBrowserProfile")
        }
        return WebKitBrowserPage(profile: webKitProfile, configuration: configuration, delegate: delegate)
    }
}
