import SwiftUI
import SwiftData
import WebKit
import AppKit

enum TabType: String, Codable {
    case pinned
    case fav
    case normal
}
struct URLUpdate: Codable {
    let href: String
    let title: String
    let favicon: String
}
// MARK: - Tab
@Model
class Tab: ObservableObject, Identifiable {
    var id: UUID
    var url: URL
    var urlString: String
    var savedURL: URL? 
    var title: String
    var favicon: URL? // Add favicon property
    var createdAt: Date
    var lastAccessedAt: Date?
    var isPlayingMedia: Bool
    var isLoading: Bool = false
    var type: TabType
    var order: Int
    var faviconLocalFile: URL?
    var backgroundColorHex: String = "#000000"
    
    
    //    @Transient @Published var backgroundColor: Color = Color(.black)
    @Transient @Published var backgroundColor: Color = .black
    @Transient var historyManager: HistoryManager? = nil
    @Transient var downloadManager: DownloadManager? = nil
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient public var navigationDelegate: WebViewNavigationDelegate?
    @Transient @Published var isWebViewReady: Bool = false
    @Transient var colorUpdated = false
    @Transient var maybeIsActive = false
    @Transient @Published var hasNavigationError: Bool = false
    @Transient @Published var navigationError: Error?
    @Transient @Published var failedURL: URL?
    
    @Relationship(inverse: \TabContainer.tabs) var container: TabContainer
    
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        favicon:URL? = nil,
        container: TabContainer,
        type: TabType = .normal,
        isPlayingMedia:Bool = false,
        order: Int,
        historyManager: HistoryManager? = nil,
        downloadManager: DownloadManager? = nil
    ) {
        let nowDate = Date()
        self.id = id
        self.url = url
        self.urlString = url.absoluteString
        
        self.title = title
        self.favicon = favicon
        self.createdAt = nowDate
        self.lastAccessedAt = nowDate
        self.type = type
        self.isPlayingMedia = isPlayingMedia
        self.container = container
        // Initialize webView with provided configuration or default
        
        let config = TabScriptHandler()
        
        self.webView = WKWebView(
            frame: .zero,
            configuration: config
                .defaultWKConfig()
        )
        
        self.order = order
        self.historyManager = historyManager
        self.downloadManager = downloadManager
        
        config.tab = self
        // Configure WebView for performance
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable layer-backed view for hardware acceleration
        webView.wantsLayer = true
        webView.isInspectable = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }
        
        // Set up navigation delegate
        
        
        // Load initial URL
        DispatchQueue.main.async {
            self.setupNavigationDelegate()
            self.syncBackgroundColorFromHex()
            self.webView.load(URLRequest(url: url))
            self.isWebViewReady = true
        }
    }
    
    func syncBackgroundColorFromHex() {
        backgroundColor = Color(hex: backgroundColorHex)
    }
    
    // Call this whenever the color is set
    func updateBackgroundColor(_ color: Color) {
        backgroundColor = color
        backgroundColorHex = color.toHex() ?? "#000000"
    }
    
    
    public func setFavicon(faviconURLDefault: URL? = nil) {
        guard let host = self.url.host else { return }
        
        let faviconURL = faviconURLDefault != nil ? faviconURLDefault! :
        URL(string: "https://www.google.com/s2/favicons?domain=\(host)")!
        self.favicon = faviconURL
        
        // Infer extension from URL or fallback to png
        let ext = faviconURL.pathExtension.isEmpty ? "png" : faviconURL.pathExtension
        let fileName = "\(self.id.uuidString).\(ext)"
        let saveURL = FileManager.default.faviconDirectory.appendingPathComponent(fileName)
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: faviconURL)
                try data.write(to: saveURL, options: .atomic)
                
                self.faviconLocalFile = saveURL
                
            } catch {
                // Failed to download/save favicon
            }
        }
    }
    func switchSections(from: Tab, to: Tab) {
        from.type = to.type
    }
    public func updateHeaderColor(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if let wv = self?.webView {
                self?.navigationDelegate?
                    .takeSnapshotAfterLoad(wv)
            }
        }
    }
    public func updateHistory(){
        
        if let historyManager = self.historyManager {
            Task { @MainActor in
                historyManager.record(
                    title: self.title,
                    url: self.url,
                    faviconURL: self.favicon,
                    faviconLocalFile: self.faviconLocalFile
                )
            }
        }
    }
    func maintainSnapShots() {
        if (!self.colorUpdated ||  self.webView.isLoading) && self.maybeIsActive  {
            self.updateHeaderColor()
            
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                guard let tab = self else { return }
                tab.maintainSnapShots()
            }
        }
    }
    private func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.tab = self
        delegate.downloadManager = self.downloadManager
        delegate.onStart = { [weak self] in
            self?.clearNavigationError()
            self?.maintainSnapShots()
        }
        delegate.onTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                
                if let title = title, !title.isEmpty {
                    self?.title = title
                }
                
            }
        }
        delegate.onURLChange = { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.url = url
                    if self?.favicon == nil {
                        self?.setFavicon()
                        
                    }
                    self?.updateHistory()
                    self?.updateHeaderColor()
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
    func goForward(){
        self.webView.goForward()
        self.updateHeaderColor()
    }
    func goBack(){
        self.webView.goBack()
        self.updateHeaderColor()
    }
    
    func restoreTransientState(historyManger: HistoryManager, downloadManager: DownloadManager? = nil) {
        // Avoid double initialization
        if webView.url != nil { return }
        
        let config = TabScriptHandler()
        self.webView = WKWebView(frame: .zero, configuration: config.defaultWKConfig())
        config.tab = self
        
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true

        webView.wantsLayer = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }
        
        self.historyManager = historyManger
        self.downloadManager = downloadManager
        self.isWebViewReady = false
        self.setupNavigationDelegate()
        self.syncBackgroundColorFromHex()
        // Load after a short delay to ensure layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.webView.load(URLRequest(url: self.url))
            self.isWebViewReady = true
        }
    }
    public func stopMedia(completed: @escaping () -> Void) {
        let js = """
        document.querySelectorAll('video, audio').forEach(el => {
            try {
                el.pause();
                el.src = '';
                el.load();
            } catch (e) {}
        });
        """
        webView.evaluateJavaScript(js) { _, _ in
            self.webView.closeAllMediaPresentations(completionHandler: completed)
        }
        webView.removeFromSuperview()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
        webView = WKWebView()
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
        // Navigation failed
    }
    
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // For now, grant all
        decisionHandler(.grant)
    }
    
    func destroyWebView() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        webView.removeFromSuperview()
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }
    
    func setNavigationError(_ error: Error, for url: URL?) {
        DispatchQueue.main.async {
            self.hasNavigationError = true
            self.navigationError = error
            self.failedURL = url
        }
    }
    
    func clearNavigationError() {
        DispatchQueue.main.async {
            self.hasNavigationError = false
            self.navigationError = nil
            self.failedURL = nil
        }
    }
    
    func retryNavigation() {
        // Don't clear error state immediately - let onStart callback handle it
        // This prevents showing white background before navigation begins
        if let url = failedURL {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

extension FileManager {
    var faviconDirectory: URL {
        let dir = urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Favicons")
        if !fileExists(atPath: dir.path) {
            try? createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}


extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            return nil
        }
        
        self.init(calibratedRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
    
    func toHex() -> String? {
        guard let color = usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        let a = Int(color.alphaComponent * 255)
        
        return a < 255
        ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
        : String(format: "#%02X%02X%02X", r, g, b)
    }
}
