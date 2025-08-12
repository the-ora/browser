// import SwiftUI
// import WebKit
//
//// MARK: - Tab Model
// class BrowserTab: Identifiable, ObservableObject {
//    let id = UUID()
//    @Published var url: URL
//    @Published var title: String
//    @Published var icon: Image?
//    @Published var isLoading: Bool = false
//    @Published var favicon: NSImage?
//    var webView: WKWebView
//    private var navigationDelegate: WebViewNavigationDelegate?
//    @Published var backgroundColor: Color = Color(nsColor: NSColor.windowBackgroundColor)
//
//    init(url: URL, title: String = "New Tab", configuration: WKWebViewConfiguration) {
//        self.url = url
//        self.title = title
//        self.webView = WKWebView(frame: .zero, configuration: configuration)
//
//        // Configure WebView for performance
//        webView.allowsMagnification = true
//        webView.allowsBackForwardNavigationGestures = true
//
//        // Enable layer-backed view for hardware acceleration
//        webView.wantsLayer = true
//        if let layer = webView.layer {
//            layer.isOpaque = true
//            layer.drawsAsynchronously = true
//        }
//
//        // Set up navigation delegate
//        setupNavigationDelegate()
//
//        // Load initial URL
//        DispatchQueue.main.async {
//            self.webView.load(URLRequest(url: url))
//        }
//    }
//
//    private func setupNavigationDelegate() {
//        let delegate = WebViewNavigationDelegate()
//        delegate.tab = self
//
//        delegate.onTitleChange = { [weak self] title in
//            DispatchQueue.main.async {
//                self?.title = title ?? "New Tab"
//            }
//        }
//        delegate.onURLChange = { [weak self] url in
//            DispatchQueue.main.async {
//                if let url = url {
//                    self?.url = url
//                }
//            }
//        }
//        delegate.onLoadingChange = { [weak self] isLoading in
//            DispatchQueue.main.async {
//                self?.isLoading = isLoading
//            }
//        }
//
//        self.navigationDelegate = delegate
//        webView.navigationDelegate = delegate
//    }
//
//    func loadURL(_ urlString: String) {
//        var finalURLString = urlString
//
//        // Add https:// if no protocol specified
//        if !urlString.contains("://") {
//            finalURLString = "https://" + urlString
//        }
//
//        if let url = URL(string: finalURLString) {
//            let request = URLRequest(url: url)
//            webView.load(request)
//        }
//    }
//
//    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
//    {
//        print("Navigation failed: \(error.localizedDescription)")
//    }
// }
