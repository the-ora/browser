import AppKit
import SwiftData
import SwiftUI
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
    @Transient var historyManager: HistoryManager?
    @Transient var downloadManager: DownloadManager?
    @Transient var tabManager: TabManager?
    // Not persisted: in-memory only
    @Transient var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    @Transient var navigationDelegate: WebViewNavigationDelegate?
    @Transient var uiDelegate: TabUIDelegate?
    @Transient @Published var isWebViewReady: Bool = false
    @Transient @Published var loadingProgress: Double = 10.0
    @Transient var colorUpdated = false
    @Transient var maybeIsActive = false
    @Transient @Published var hasNavigationError: Bool = false
    @Transient @Published var navigationError: Error?
    @Transient @Published var failedURL: URL?
    @Transient @Published var hoveredLinkURL: String?

    @Relationship(inverse: \TabContainer.tabs) var container: TabContainer

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        favicon: URL? = nil,
        container: TabContainer,
        type: TabType = .normal,
        isPlayingMedia: Bool = false,
        order: Int,
        historyManager: HistoryManager? = nil,
        downloadManager: DownloadManager? = nil,
        tabManager: TabManager
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
        self.tabManager = tabManager

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

        // Set up navigation delegate and UI delegate

        // Load initial URL
        DispatchQueue.main.async {
            self.setupNavigationDelegate()
            self.setupUIDelegate()
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

    func setFavicon(faviconURLDefault: URL? = nil) {
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

    private func setupNavigationDelegate() {
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

    private func setupUIDelegate() {
        print("🎥 setupUIDelegate")
        let delegate = TabUIDelegate(tab: self)
        self.uiDelegate = delegate
        webView.uiDelegate = delegate
    }

    func goForward() {
        self.webView.goForward()
        self.updateHeaderColor()
    }

    func goBack() {
        self.webView.goBack()
        self.updateHeaderColor()
    }

    func restoreTransientState(
        historyManger: HistoryManager,
        downloadManager: DownloadManager,
        tabManager: TabManager
    ) {
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
        self.tabManager = tabManager
        self.isWebViewReady = false
        self.setupNavigationDelegate()
        print("🎥 setupUIDelegate")
        self.setupUIDelegate()
        self.syncBackgroundColorFromHex()
        // Load after a short delay to ensure layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.webView.load(URLRequest(url: self.url))
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

    func destroyWebView() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        webView.removeFromSuperview()

        let config = TabScriptHandler()
        config.tab = self
        webView = WKWebView(frame: .zero, configuration: config.defaultWKConfig())
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

// MARK: - TabUIDelegate

class TabUIDelegate: NSObject, WKUIDelegate {
    weak var tab: Tab?

    init(tab: Tab) {
        self.tab = tab
        super.init()
        // TabUIDelegate initialized
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let host = origin.host
        print("🎥 TabUIDelegate: Requesting \(type) for \(host)")
        // Handle media capture permission request

        // Determine which permission type is being requested
        print("🎥 Media capture type raw value: \(type.rawValue)")

        let permissionType: PermissionKind
        switch type.rawValue {
        case 0: // .camera
            print("🎥 Camera only request")
            permissionType = .camera
        case 1: // .microphone
            print("🎥 Microphone only request")
            permissionType = .microphone
        case 2: // .cameraAndMicrophone
            print("🎥 Camera and microphone request")
            handleCameraAndMicrophonePermission(host: host, webView: webView, decisionHandler: decisionHandler)
            return
        default:
            print("🎥 Unknown media capture type: \(type.rawValue)")
            decisionHandler(.deny)
            return
        }

        // Check if we already have this specific permission configured
        if let existingPermission = PermissionManager.shared.getExistingPermission(for: host, type: permissionType) {
            decisionHandler(existingPermission ? .grant : .deny)
            return
        }

        // Request new permission with timeout safety
        var hasResponded = false

        // Set up a timeout to ensure decision handler is always called
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if !hasResponded {
                hasResponded = true
                decisionHandler(.deny) // Default to deny if no response
            }
        }

        // Request the specific permission
        Task { @MainActor in
            PermissionManager.shared.requestPermission(
                for: permissionType,
                from: host,
                webView: webView
            ) { allowed in
                if !hasResponded {
                    hasResponded = true
                    decisionHandler(allowed ? .grant : .deny)
                }
            }
        }
    }

    private func handleCameraAndMicrophonePermission(
        host: String,
        webView: WKWebView,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        print("🎥 handleCameraAndMicrophonePermission called for \(host)")
        // Handle combined camera and microphone permission request

        // Check if we already have both permissions configured
        let cameraPermission = PermissionManager.shared.getExistingPermission(for: host, type: .camera)
        let microphonePermission = PermissionManager.shared.getExistingPermission(for: host, type: .microphone)

        if let cameraAllowed = cameraPermission, let microphoneAllowed = microphonePermission {
            let shouldGrant = cameraAllowed && microphoneAllowed
            decisionHandler(shouldGrant ? .grant : .deny)
            return
        }

        // Request permissions sequentially with timeout safety
        var hasResponded = false

        // Set up a timeout to ensure decision handler is always called
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if !hasResponded {
                hasResponded = true
                decisionHandler(.deny) // Default to deny if no response
            }
        }

        Task { @MainActor in
            print("🎥 Requesting camera permission first...")
            // First request camera permission
            PermissionManager.shared.requestPermission(
                for: .camera,
                from: host,
                webView: webView
            ) { cameraAllowed in
                print("🎥 Camera permission result: \(cameraAllowed), now requesting microphone...")

                // Add a small delay to ensure the first request is fully cleared
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Then request microphone permission
                    PermissionManager.shared.requestPermission(
                        for: .microphone,
                        from: host,
                        webView: webView
                    ) { microphoneAllowed in
                        print("🎥 Microphone permission result: \(microphoneAllowed)")
                        if !hasResponded {
                            hasResponded = true
                            // Grant only if both are allowed
                            let shouldGrant = cameraAllowed && microphoneAllowed
                            print("🎥 Final decision: \(shouldGrant)")
                            decisionHandler(shouldGrant ? .grant : .deny)
                        }
                    }
                }
            }
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
