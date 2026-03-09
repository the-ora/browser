import AppKit
import Foundation

protocol BrowserPageDelegate: AnyObject {
    func browserPage(
        _ page: BrowserPage,
        decidePolicyFor navigationAction: BrowserNavigationAction
    ) -> BrowserNavigationActionDisposition
    func browserPage(_ page: BrowserPage, didRequestOpenInNewTab url: URL)
    func browserPage(_ page: BrowserPage, didUpdateNavigation event: BrowserNavigationEvent)
    func browserPage(_ page: BrowserPage, didFailNavigationWith error: Error, failingURL: URL?)
    func browserPage(_ page: BrowserPage, didReceiveScriptMessage message: BrowserScriptMessage)
    func browserPage(
        _ page: BrowserPage,
        requestPermission permission: BrowserPermissionKind,
        origin: URL?,
        decisionHandler: @escaping (BrowserPermissionDecision) -> Void
    )
    func browserPage(
        _ page: BrowserPage,
        runOpenPanelWith options: BrowserOpenPanelOptions,
        completion: @escaping ([URL]?) -> Void
    )
    func browserPage(_ page: BrowserPage, runJavaScriptAlert message: String)
    func browserPage(_ page: BrowserPage, runJavaScriptConfirm message: String, completion: @escaping (Bool) -> Void)
    func browserPage(_ page: BrowserPage, didStartDownload download: BrowserDownloadTask)
}

extension BrowserPageDelegate {
    func browserPage(
        _ page: BrowserPage,
        decidePolicyFor navigationAction: BrowserNavigationAction
    ) -> BrowserNavigationActionDisposition {
        .allow
    }

    func browserPage(_ page: BrowserPage, didRequestOpenInNewTab url: URL) {}

    func browserPage(_ page: BrowserPage, didUpdateNavigation event: BrowserNavigationEvent) {}

    func browserPage(_ page: BrowserPage, didFailNavigationWith error: Error, failingURL: URL?) {}

    func browserPage(_ page: BrowserPage, didReceiveScriptMessage message: BrowserScriptMessage) {}

    func browserPage(
        _ page: BrowserPage,
        requestPermission permission: BrowserPermissionKind,
        origin: URL?,
        decisionHandler: @escaping (BrowserPermissionDecision) -> Void
    ) {
        decisionHandler(.deny)
    }

    func browserPage(
        _ page: BrowserPage,
        runOpenPanelWith options: BrowserOpenPanelOptions,
        completion: @escaping ([URL]?) -> Void
    ) {
        completion(nil)
    }

    func browserPage(_ page: BrowserPage, runJavaScriptAlert message: String) {}

    func browserPage(_ page: BrowserPage, runJavaScriptConfirm message: String, completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func browserPage(_ page: BrowserPage, didStartDownload download: BrowserDownloadTask) {}
}

class BrowserDownloadTask: NSObject {
    let id = UUID()
    var originalURL: URL
    var onDestinationRequest: ((URLResponse, String, @escaping (URL?) -> Void) -> Void)?
    var onRedirect: ((URL) -> Void)?
    var onFinish: (() -> Void)?
    var onFail: ((Error) -> Void)?

    init(originalURL: URL) {
        self.originalURL = originalURL
        super.init()
    }

    var progress: Progress {
        Progress(totalUnitCount: 0)
    }

    func cancel() {}
}

class BrowserPage: NSObject {
    let engineKind: BrowserEngineKind
    weak var delegate: BrowserPageDelegate?

    init(engineKind: BrowserEngineKind, delegate: BrowserPageDelegate? = nil) {
        self.engineKind = engineKind
        self.delegate = delegate
        super.init()
    }

    var contentView: NSView {
        preconditionFailure("BrowserPage subclasses must provide a content view")
    }

    var window: NSWindow? {
        contentView.window
    }

    var currentURL: URL? {
        nil
    }

    var title: String? {
        nil
    }

    var canGoBack: Bool {
        false
    }

    var canGoForward: Bool {
        false
    }

    var isLoading: Bool {
        false
    }

    var estimatedProgress: Double {
        0
    }

    func load(_ request: URLRequest) {}

    func reload() {}

    func goBack() {}

    func goForward() {}

    func stopLoading() {}

    func evaluateJavaScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        completion?(nil, nil)
    }

    func takeSnapshot(
        configuration: BrowserSnapshotConfiguration,
        completion: @escaping (NSImage?, Error?) -> Void
    ) {
        completion(nil, nil)
    }

    func closeMediaPresentations(completion: @escaping () -> Void) {
        completion()
    }

    func teardown() {}
}
