import SwiftUI
import SwiftData
import WebKit

enum TabType: String, Codable {
    case pinned
    case fav
    case normal
}
// MARK: - Tab
@Model
class Tab: ObservableObject, Identifiable {
    var id: UUID
    var url: URL
    var title: String
    var favicon: URL? // Add favicon property
    var createdAt: Date
    var lastAccessedAt: Date?
    var isPlayingMedia: Bool
    var isLoading: Bool = false
    var type: TabType
    var order: Int

    @Transient var backgroundColor: Color = Color(.black)
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient private var navigationDelegate: WebViewNavigationDelegate?
    @Transient @Published var isWebViewReady: Bool = false

    @Relationship(inverse: \TabContainer.tabs) var container: TabContainer
    
    init(id: UUID = UUID(), url: URL, title: String, favicon:URL? = nil, container: TabContainer, type: TabType = .normal, isPlayingMedia:Bool = false, webViewConfiguration: WKWebViewConfiguration? = nil,order: Int) {
        let nowDate = Date()
        self.id = id
        self.url = url
        self.title = title
        self.favicon = favicon
        self.createdAt = nowDate
        self.lastAccessedAt = nowDate
        self.type = type
        self.isPlayingMedia = isPlayingMedia
        self.container = container
        self.backgroundColor = Color(.black)
        // Initialize webView with provided configuration or default
        self.webView = WKWebView(
            frame: .zero,
            configuration: defaultWKConfig()
        )
        self.order = order
        // Configure WebView for performance
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable layer-backed view for hardware acceleration
        webView.wantsLayer = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }
        
        // Set up navigation delegate
        setupNavigationDelegate()
        
        // Load initial URL
        DispatchQueue.main.async {
            self.webView.load(URLRequest(url: url))
            self.isWebViewReady = true
        }
    }
    public func setFavicon(){
        if let host = self.url.host {
            let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)")
            self.favicon = faviconURL
        }
    }
    func switchSections(from: Tab, to: Tab) {
        from.type = to.type
    }
    private func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.tab = self
        
        delegate.onTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                self?.title = title ?? "New Tab"
            }
        }
        delegate.onURLChange = { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.url = url
                    self?.setFavicon()
                }
                
            }
        }
        delegate.onLoadingChange = { [weak self] isLoading in
            DispatchQueue.main.async {
                self?.isLoading = isLoading
            }
        }
        
        self.navigationDelegate = delegate
        webView.navigationDelegate = delegate
    }
    
    func restoreTransientState() {
        // Avoid double initialization
        if webView.url != nil { return }

        self.backgroundColor = Color(.black)
        self.webView = WKWebView(frame: .zero, configuration: defaultWKConfig())

        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true
        webView.wantsLayer = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }


        self.isWebViewReady = false
        self.setupNavigationDelegate()
        // Load after a short delay to ensure layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.webView.load(URLRequest(url: self.url))
            self.isWebViewReady = true
        }
    }
    
    func loadURL(_ urlString: String) {
        var finalURLString = urlString
        
        // Add https:// if no protocol specified
        if !urlString.contains("://") {
            finalURLString = "https://" + urlString
        }
        
        if let url = URL(string: finalURLString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }
}
