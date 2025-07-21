import SwiftUI
import SwiftData
import WebKit

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
    var title: String
    var favicon: URL? // Add favicon property
    var createdAt: Date
    var lastAccessedAt: Date?
    var isPlayingMedia: Bool
    var isLoading: Bool = false
    var type: TabType
    var order: Int
    var faviconLocalFile: URL?
    
    @Transient var backgroundColor: Color = Color(.black)
    @Transient var historyManager: HistoryManager? = nil
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient private var navigationDelegate: WebViewNavigationDelegate?
    @Transient @Published var isWebViewReady: Bool = false
    
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
        historyManager: HistoryManager? = nil
    ) {
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
        
        let config = TabScriptHandler()
        
        self.webView = WKWebView(
            frame: .zero,
            configuration: config
                .defaultWKConfig()
        )
        
        self.order = order
        self.historyManager = historyManager
        
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
            self.webView.load(URLRequest(url: url))
            self.isWebViewReady = true
        }
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
                  DispatchQueue.main.async {
                      self.faviconLocalFile = saveURL
                  }
              } catch {
                  print("⚠️ Failed to download/save favicon: \(error)")
              }
          }
    }
    func switchSections(from: Tab, to: Tab) {
        from.type = to.type
    }
    public func updateHistory(){
        if let historyManager = self.historyManager {
            Task { @MainActor in
                historyManager.record(
                    title: self.title,
                    url: self.url
                )
            }
        }
    }
    private func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.tab = self
        
        delegate.onChange = { [weak self] title, url in
            DispatchQueue.main.async {
                if let title = title, let url = url  {
                    self?.updateHistory()
                }
                //                self?.title = title
                //                self?.url = url
                //                self?.setFavicon()
            }
            
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
    
    func restoreTransientState(historyManger: HistoryManager) {
        // Avoid double initialization
        if webView.url != nil { return }
        
        self.backgroundColor = Color(.black)
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
