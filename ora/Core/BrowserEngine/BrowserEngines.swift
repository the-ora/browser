import Foundation

final class BrowserEngines {
    // TODO(CEF): Replace the hard-coded WebKit default with persisted engine selection
    // after the macOS CEF host, helper app packaging, and signing flow are integrated.
    static let shared = BrowserEngines(current: WebKitBrowserEngine())

    var current: BrowserEngine

    init(current: BrowserEngine) {
        self.current = current
    }
}
