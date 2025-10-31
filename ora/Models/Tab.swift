import AppKit
import SwiftData
import SwiftUI
import WebKit

// Import for accessing settings

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

    private(set) var type: TabType
    var order: Int
    var faviconLocalFile: URL?
    var backgroundColorHex: String = "#000000"

    //    @Transient @Published var backgroundColor: Color = Color(.black)
    @Transient var isPlayingMedia: Bool = false
    @Transient var isLoading: Bool = false
    @Transient @Published var backgroundColor: Color = .black
    @Transient var historyManager: HistoryManager?
    @Transient var downloadManager: DownloadManager?
    @Transient var tabManager: TabManager?
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient var navigationDelegate: WebViewNavigationDelegate?
    @Transient @Published var isWebViewReady: Bool = false
    @Transient @Published var loadingProgress: Double = 10.0
    @Transient var colorUpdated = false
    @Transient var maybeIsActive = false
    @Transient @Published var hasNavigationError: Bool = false
    @Transient @Published var navigationError: Error?
    @Transient @Published var failedURL: URL?
    @Transient @Published var hoveredLinkURL: String?
    @Transient var isPrivate: Bool = false

    @Relationship(inverse: \TabContainer.tabs) var container: TabContainer
    @Relationship(deleteRule: .cascade) var children: [Tab]
    @Relationship(inverse: \Tab.children) var parent: Tab?
    @Relationship(inverse: \TabTileset.tabs) var tileset: TabTileset?

    /// Whether this tab is considered alive (recently accessed)
    var isAlive: Bool {
        guard let lastAccessed = lastAccessedAt else { return false }
        let timeout = SettingsStore.shared.tabAliveTimeout
        return Date().timeIntervalSince(lastAccessed) < timeout
    }

    init(
        id: UUID = UUID(),
        parent: Tab? = nil,
        url: URL,
        title: String,
        favicon: URL? = nil,
        container: TabContainer,
        type: TabType = .normal,
        isPlayingMedia: Bool = false,
        order: Int,
        historyManager: HistoryManager? = nil,
        downloadManager: DownloadManager? = nil,
        tabManager: TabManager,
        isPrivate: Bool
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

        // Tab hierarchy setup
        self.children = []
        self.parent = parent

        let config = TabScriptHandler()

        self.webView = WKWebView(
            frame: .zero,
            configuration: config
                .customWKConfig(
                    containerId: container.id,
                    temporaryStorage: isPrivate
                ) // if private it's gonna use in-memory storage
        )

        self.order = order
        self.historyManager = historyManager
        self.downloadManager = downloadManager
        self.tabManager = tabManager
        self.isPrivate = isPrivate

        config.tab = self
        config.mediaController = tabManager.mediaController
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

        // Don't automatically load URL - let TabManager handle it
        // This prevents all tabs from loading on app launch
        self.isWebViewReady = false
    }

    func syncBackgroundColorFromHex() {
        backgroundColor = Color(hex: backgroundColorHex)
    }

    // Call this whenever the color is set
    func updateBackgroundColor(_ color: Color) {
        backgroundColor = color
        backgroundColorHex = color.toHex() ?? "#000000"
    }

    func setFavicon(faviconURLDefault: URL? = nil) {
        guard let host = self.url.host else { return }

        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let faviconURL = faviconURLDefault ?? URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")!
        self.favicon = faviconURL

        // Infer extension from URL or fallback to png
        let ext = faviconURL.pathExtension.isEmpty ? "png" : faviconURL.pathExtension
        let fileName = "\(self.id.uuidString).\(ext)"
        let saveURL = FileManager.default.faviconDirectory.appendingPathComponent(fileName)

        FaviconService.shared
            .downloadAndSaveFavicon(for: domain, faviconURL: faviconURL, to: saveURL) {
                [weak self] sourceURL, success in
                guard let self else { return }
                if success {
                    Task { @MainActor in
                        self.faviconLocalFile = saveURL
                        if let sourceURL {
                            self.favicon = sourceURL
                        }
                    }
                }
            }
    }

    func switchSections(from: Tab, to: Tab) {
        from.type = to.type
        switch to.type {
        case .pinned, .fav:
            from.savedURL = from.url
        case .normal:
            from.savedURL = nil
        }
    }

    func switchSections(to sec: TabType) {
        type = sec
        savedURL = switch sec {
        case .pinned, .fav:
            url
        case .normal:
            nil
        }
    }

    func updateHeaderColor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if let wv = self?.webView {
                self?.navigationDelegate?
                    .takeSnapshotAfterLoad(wv)
            }
        }
    }

    func updateHistory() {
        if let historyManager = self.historyManager {
            Task { @MainActor in
                historyManager.record(
                    title: self.title,
                    url: self.url,
                    faviconURL: self.favicon,
                    faviconLocalFile: self.faviconLocalFile,
                    container: self.container
                )
            }
        }
    }

    func maintainSnapShots() {
        if !self.colorUpdated ||  self.webView.isLoading, self.maybeIsActive {
            self.updateHeaderColor()

            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                guard let tab = self else { return }
                tab.maintainSnapShots()
            }
        }
    }

    func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.tab = self
        delegate.onStart = { [weak self] in
            self?.clearNavigationError()
            self?.maintainSnapShots()
        }
        delegate.onTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                if let title, !title.isEmpty {
                    self?.title = title
                    if let self {
                        self.tabManager?.mediaController.syncTitleForTab(self.id, newTitle: title)
                    }
                }
            }
        }
        delegate.onURLChange = { [weak self] url in
            DispatchQueue.main.async {
                if let url {
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

        delegate.onProgressChange = { [weak self] progress in
            DispatchQueue.main.async {
                self?.loadingProgress = progress
            }
        }

        self.navigationDelegate = delegate
        webView.navigationDelegate = delegate
    }

    func goForward() {
        lastAccessedAt = Date()
        self.webView.goForward()
        self.updateHeaderColor()
    }

    func goBack() {
        lastAccessedAt = Date()
        self.webView.goBack()
        self.updateHeaderColor()
    }

    func restoreTransientState(
        historyManager: HistoryManager,
        downloadManager: DownloadManager,
        tabManager: TabManager,
        isPrivate: Bool
    ) {
        // Avoid double initialization
        if webView.url != nil { return }

        let config = TabScriptHandler()

        config.tab = self
        config.mediaController = tabManager.mediaController
        self.webView = WKWebView(
            frame: .zero,
            configuration: config
                .customWKConfig(
                    containerId: self.container.id,
                    temporaryStorage: isPrivate
                )
        )
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = true

        webView.wantsLayer = true
        if let layer = webView.layer {
            layer.isOpaque = true
            layer.drawsAsynchronously = true
        }

        self.historyManager = historyManager
        self.downloadManager = downloadManager
        self.tabManager = tabManager
        self.isWebViewReady = false
        self.setupNavigationDelegate()
        self.syncBackgroundColorFromHex()
        // Load after a short delay to ensure layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let url = if self.type != .normal { self.savedURL } else { self.url }
            self.webView.load(URLRequest(url: url ?? self.url))
            self.isWebViewReady = true
        }
    }

    func stopMedia(completed: @escaping () -> Void) {
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
        lastAccessedAt = Date()
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Try to construct a direct URL (has scheme or valid domain+TLD/IP)
        if let directURL = constructURL(from: input) {
            webView.load(URLRequest(url: directURL))
            return
        }

        // 2) Otherwise, treat as a search query using the selected search engine
        let searchEngineService = SearchEngineService()
        if let engine = searchEngineService.getDefaultSearchEngine(for: self.container.id),
           let searchURL = searchEngineService.createSearchURL(for: engine, query: input)
        {
            webView.load(URLRequest(url: searchURL))
            return
        }

        // 3) Fallback to Google if for some reason engine lookup fails
        if let fallbackURL = URL(string: "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q="
            + (input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        ) {
            webView.load(URLRequest(url: fallbackURL))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Navigation failed
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
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
        isWebViewReady = false
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

    func dissociateFromRelatives() {
        if let parent = self.parent {
            parent.children.removeAll(where: { $0.id == id })
            for child in parent.children {
                if child.order > self.order {
                    child.order -= 1
                }
            }
        } else {
            for sibling in container.tabs where sibling.type == type {
                if sibling.order > self.order {
                    sibling.order -= 1
                }
            }
        }
    }

    func abandonChildren() {
        for child in children {
            child.parent = parent
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

        // swiftlint:disable:next identifier_name
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
        // swiftlint:disable:next identifier_name
        let r = Int(color.redComponent * 255)
        // swiftlint:disable:next identifier_name
        let g = Int(color.greenComponent * 255)
        // swiftlint:disable:next identifier_name
        let b = Int(color.blueComponent * 255)
        // swiftlint:disable:next identifier_name
        let a = Int(color.alphaComponent * 255)

        return a < 255
            ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
            : String(format: "#%02X%02X%02X", r, g, b)
    }
}
