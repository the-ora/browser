import SwiftUI
import WebKit

// MARK: - Tab Model
class BrowserTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var url: URL
    @Published var title: String
    @Published var icon: Image?
    @Published var isLoading: Bool = false
    @Published var favicon: NSImage?
    let webView: WKWebView
    private var navigationDelegate: WebViewNavigationDelegate?
    
    init(url: URL, title: String = "New Tab", configuration: WKWebViewConfiguration) {
        self.url = url
        self.title = title
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        
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
        }
    }
    
    private func setupNavigationDelegate() {
        let delegate = WebViewNavigationDelegate()
        delegate.onTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                self?.title = title ?? "New Tab"
            }
        }
        delegate.onURLChange = { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.url = url
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
}

// MARK: - Tab Manager
class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabId: UUID?
    
    private var webViewConfiguration: WKWebViewConfiguration
    
    var selectedTab: BrowserTab? {
        guard let selectedTabId = selectedTabId else { return nil }
        return tabs.first { $0.id == selectedTabId }
    }
    
    init() {
        // Configure WebView for performance
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = "OraBrowser/1.0"
        
        // Performance optimizations
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Enable process pool for better memory management
        let processPool = WKProcessPool()
        configuration.processPool = processPool
        
        // Enable media playback without user interaction
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Set up caching
        let websiteDataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = websiteDataStore
        
        // GPU acceleration settings
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        self.webViewConfiguration = configuration
        
        // Create initial tab
        addTab()
    }
    
    func addTab(url: URL = URL(string: "https://www.apple.com")!) {
        let newTab = BrowserTab(url: url, configuration: webViewConfiguration)
        tabs.append(newTab)
        selectedTabId = newTab.id
    }
    
    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return } // Don't close the last tab
        
        let index = tabs.firstIndex { $0.id == id } ?? 0
        tabs.remove(at: index)
        
        // Select an adjacent tab if the closed tab was selected
        if selectedTabId == id {
            let newIndex = min(index, tabs.count - 1)
            selectedTabId = tabs[newIndex].id
        }
    }
    
    func selectTab(id: UUID) {
        selectedTabId = id
    }
}

// MARK: - Sidebar Tab Item
struct TabItem: View {
    @ObservedObject var tab: BrowserTab
    var isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Favicon or default icon
            faviconView
                .frame(width: 16, height: 16)
                .cornerRadius(4)
            
            // Tab title
            if isSelected || isHovering {
                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Spacer()
            
            // Close button or loading indicator
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else if (isHovering || isSelected) {
                closeButton
            }
        }
        .padding(.horizontal, isSelected ? 12 : 8)
        .padding(.vertical, 8)
        .background(backgroundView)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    private var faviconView: some View {
        Group {
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Text(String(tab.title.prefix(1).uppercased()))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
        } else if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Sidebar
struct Sidebar: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isSidebarVisible: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with search and profile
            VStack(spacing: 16) {
                // Profile section
                HStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("U")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    Button(action: {
                        tabManager.addTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField("Search tabs...", text: $searchText)
                        .font(.system(size: 13))
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Tabs section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Pinned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Tab list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(tabManager.tabs) { tab in
                            TabItem(
                                tab: tab,
                                isSelected: tab.id == tabManager.selectedTabId,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        tabManager.selectTab(id: tab.id)
                                    }
                                },
                                onClose: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        tabManager.closeTab(id: tab.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            Spacer()
            
            // Bottom section
            VStack(spacing: 12) {
                Divider()
                    .opacity(0.3)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 280)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ?
                      Color.black.opacity(0.3) :
                      Color.white.opacity(0.8))
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: URL Bar
struct URLBar: View {
    @ObservedObject var tab: BrowserTab
    @State private var editingURLString: String = ""
    @State private var isEditing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 8) {
                NavigationButton(
                    systemName: "chevron.left",
                    isEnabled: tab.webView.canGoBack,
                    action: { tab.webView.goBack() }
                )
                
                NavigationButton(
                    systemName: "chevron.right",
                    isEnabled: tab.webView.canGoForward,
                    action: { tab.webView.goForward() }
                )
                
                NavigationButton(
                    systemName: "arrow.clockwise",
                    isEnabled: true,
                    action: { tab.webView.reload() }
                )
            }
            
            // URL field
            HStack(spacing: 8) {
                // Security indicator
                if !isEditing {
                    Group {
                        if tab.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: tab.url.scheme == "https" ? "lock.fill" : "globe")
                                .font(.system(size: 12))
                                .foregroundColor(tab.url.scheme == "https" ? .green : .secondary)
                        }
                    }
                    .frame(width: 16)
                }
                
                TextField("", text: $editingURLString)
                    .font(.system(size: 14, weight: .medium))
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        tab.loadURL(editingURLString)
                        isEditing = false
                    }
                    .onTapGesture {
                        isEditing = true
                        editingURLString = tab.url.absoluteString
                    }
                    .overlay(
                        Group {
                            if !isEditing && editingURLString.isEmpty {
                                HStack {
                                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ?
                          Color.white.opacity(0.1) :
                          Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isEditing ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onReceive(tab.$url) { newURL in
            if !isEditing {
                editingURLString = newURL.absoluteString
            }
        }
        .onAppear {
            editingURLString = tab.url.absoluteString
        }
    }
}

// MARK: - Navigation Button
struct NavigationButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? (isHovering ? .primary : .secondary) : .secondary.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isHovering && isEnabled ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - WebView Wrapper for macOS
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        webView.autoresizingMask = [.width, .height]
        
        // Enable hardware acceleration
        webView.layer?.isOpaque = true
        webView.layer?.drawsAsynchronously = true
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No need to reload - the tab handles navigation
    }
}

// MARK: - WebView Navigation Delegate
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
        onURLChange?(webView.url)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)
        onTitleChange?(webView.title)
        onURLChange?(webView.url)
        
        // Inject performance optimization script
        let script = """
        // Force GPU rendering for smooth scrolling
        document.body.style.transform = 'translateZ(0)';
        document.body.style.backfaceVisibility = 'hidden';
        
        // Enable hardware acceleration for elements
        const acceleratedElements = document.querySelectorAll('div, img, video, canvas');
        acceleratedElements.forEach(el => {
            el.style.transform = 'translateZ(0)';
            el.style.backfaceVisibility = 'hidden';
        });
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var isSidebarVisible = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                Sidebar(tabManager: tabManager, isSidebarVisible: $isSidebarVisible)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Main browser content
            VStack(spacing: 0) {
                if let selectedTab = tabManager.selectedTab {
                    URLBar(tab: selectedTab)
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                    
                    // Web content
                    WebView(webView: selectedTab.webView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: isSidebarVisible ? 0 : 12))
                } else {
                    // Empty state
                    VStack(spacing: 20) {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "globe")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 8) {
                            Text("Welcome to Ora")
                                .font(.system(size: 24, weight: .semibold))
                            
                            Text("Create a new tab to get started")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Button("New Tab") {
                            tabManager.addTab()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isSidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
