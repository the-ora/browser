import AppKit
import SwiftData
import SwiftUI
import WebKit

// MARK: - Extensions Popup View

struct ExtensionsPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var tabManager: TabManager

    @State private var cameraPermission: PermissionState = .ask
    @State private var microphonePermission: PermissionState = .ask

    enum PermissionState: String, CaseIterable {
        case ask = "Ask"
        case allow = "Allow"
        case block = "Block"

        var next: PermissionState {
            switch self {
            case .ask: return .allow
            case .allow: return .block
            case .block: return .allow  // Don't go back to .ask
            }
        }
    }

    private var currentHost: String {
        return tabManager.activeTab?.url.host ?? "example.com"
    }

    private func togglePermission(_ kind: PermissionKind, currentState: Binding<PermissionState>) {
        let newState = currentState.wrappedValue.next
        currentState.wrappedValue = newState
        let isAllowed = newState == .allow

        // Update SwiftData
        updateSitePermission(for: kind, allow: isAllowed)

        // Notify the web view of the permission change
        if let tab = tabManager.activeTab {
            // Get the current URL and host
            let currentURL = tab.url
            let currentHost = currentURL.host ?? ""

            // Force the web view to re-evaluate permissions by temporarily changing the URL
            // This is a workaround to trigger a permission re-evaluation without a full page reload
            if currentURL.absoluteString.hasPrefix("http") {
                // Create a temporary URL with a different fragment to force a navigation
                var components = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)!
                let currentFragment = components.fragment ?? ""
                components.fragment = currentFragment.isEmpty ? "_" : ""

                if let tempURL = components.url {
                    // Store the original URL
                    let originalURL = currentURL

                    // Navigate to the temporary URL
                    tab.webView.load(URLRequest(url: tempURL))

                    // After a short delay, navigate back to the original URL
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        tab.webView.load(URLRequest(url: originalURL))
                    }
                }
            }
        }
    }

    private func updateSitePermission(for kind: PermissionKind, allow: Bool) {
        let host = currentHost

        // Find existing site permission or create new one
        let descriptor = FetchDescriptor<SitePermission>(
            predicate: #Predicate<SitePermission> { site in
                site.host.localizedStandardContains(host)
            }
        )

        let existingSite = try? modelContext.fetch(descriptor).first
        let site = existingSite ?? {
            let newSite = SitePermission(host: host)
            modelContext.insert(newSite)
            return newSite
        }()

        // Update the specific permission
        switch kind {
        case .camera:
            site.cameraAllowed = allow
            site.cameraConfigured = true
        case .microphone:
            site.microphoneAllowed = allow
            site.microphoneConfigured = true
        default:
            // All other permission types are not handled
            break
        }

        try? modelContext.save()
    }

    private func loadCurrentPermissions() {
        let host = currentHost

        let descriptor = FetchDescriptor<SitePermission>(
            predicate: #Predicate<SitePermission> { site in
                site.host.localizedStandardContains(host)
            }
        )

        if let site = try? modelContext.fetch(descriptor).first {
            cameraPermission = site.cameraConfigured ? (site.cameraAllowed ? .allow : .block) : .ask
            microphonePermission = site.microphoneConfigured ? (site.microphoneAllowed ? .allow : .block) : .ask
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Media Permissions
            VStack(alignment: .leading, spacing: 8) {
                Text("Media Permissions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Button(action: { togglePermission(.camera, currentState: $cameraPermission) }) {
                    PopupPermissionRow(icon: "camera", title: "Camera", status: cameraPermission.rawValue)
                }
                .buttonStyle(.plain)

                Button(action: { togglePermission(.microphone, currentState: $microphonePermission) }) {
                    PopupPermissionRow(icon: "mic", title: "Microphone", status: microphonePermission.rawValue)
                }
                .buttonStyle(.plain)

                SettingsLink {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)

                        Text("More settings")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    dismiss()
                }
            }

            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            loadCurrentPermissions()
        }
    }
}

struct PopupActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ExtensionIcon: View {
    let index: Int

    private var iconName: String {
        let icons = [
            "doc.text",
            "globe",
            "circle.fill",
            "square.grid.2x2",
            "star.fill",
            "folder",
            "paintbrush",
            "plus.circle",
            "photo",
            "camera",
            "map",
            "gamecontroller",
            "music.note",
            "video",
            "textformat",
            "gear"
        ]
        return icons[index % icons.count]
    }

    private var iconColor: Color {
        let colors: [Color] = [.blue, .green, .red, .orange, .purple, .pink, .yellow, .gray]
        return colors[index % colors.count]
    }

    var body: some View {
        Button(action: {}) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct BoostRow: View {
    let icon: String
    let title: String
    let status: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(status)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .green : .secondary)
            }

            Spacer()
        }
    }
}

struct PopupPermissionRow: View {
    let icon: String
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(status == "Allow" ? .green : status == "Block" ? .red : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - URLBar

struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState

    @State private var showCopiedAnimation = false
    @State private var startWheelAnimation = false
    @State private var editingURLString: String = ""
    @FocusState private var isEditing: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var showExtensionsPopup = false

    let onSidebarToggle: () -> Void

    private func getForegroundColor(_ tab: Tab) -> Color {
        // Convert backgroundColor to NSColor for luminance calculation
        let nsColor = NSColor(tab.backgroundColor)
        if let ciColor = CIColor(color: nsColor) {
            let luminance = 0.299 * ciColor.red + 0.587 * ciColor.green + 0.114 * ciColor.blue
            let baseColor: Color = luminance < 0.5 ? .white : .black
            return baseColor
        } else {
            // Fallback to black if CIColor conversion fails
            return .black
        }
    }

    private func getUrlFieldColor(_ tab: Tab) -> Color {
        return tabManager.activeTab.map { getForegroundColor($0).opacity(isEditing ? 1.0 : 0.5) } ?? .gray
    }

    private func triggerCopy(_ text: String) {
        ClipboardUtils.triggerCopy(
            text,
            showCopiedAnimation: $showCopiedAnimation,
            startWheelAnimation: $startWheelAnimation
        )
    }

    var buttonForegroundColor: Color {
        return tabManager.activeTab.map { getForegroundColor($0).opacity(0.5) } ?? .gray
    }

    private func getDisplayURL(_ tab: Tab) -> String {
        if appState.showFullURL {
            return tab.url.absoluteString
        } else {
            return tab.url.host ?? tab.url.absoluteString
        }
    }

    private func shareCurrentPage(tab: Tab, sourceView: NSView, sourceRect: NSRect) {
        let url = tab.url
        let title = tab.title.isEmpty ? "Shared from Ora" : tab.title
        let items: [Any] = [title, url]

        let picker = NSSharingServicePicker(items: items)
        picker.delegate = nil

        DispatchQueue.main.async {
            picker.show(relativeTo: sourceRect, of: sourceView, preferredEdge: .minY)
        }
    }

    var body: some View {
        HStack {
            if let tab = tabManager.activeTab {
                HStack(spacing: 4) {
                    URLBarButton(
                        systemName: "sidebar.left",
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        action: onSidebarToggle
                    )
                    .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)

                    // Back button
                    URLBarButton(
                        systemName: "chevron.left",
                        isEnabled: tabManager.activeTab?.webView.canGoBack ?? false,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goBack()
                            }
                        }
                    )
                    .oraShortcut(KeyboardShortcuts.Navigation.back)
                    .oraShortcutHelp("Go Back", for: KeyboardShortcuts.Navigation.back)

                    // Forward button
                    URLBarButton(
                        systemName: "chevron.right",
                        isEnabled: tabManager.activeTab?.webView.canGoForward ?? false,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goForward()
                            }
                        }
                    )
                    .oraShortcut(KeyboardShortcuts.Navigation.forward)
                    .oraShortcutHelp("Go Forward", for: KeyboardShortcuts.Navigation.forward)

                    // Reload button
                    URLBarButton(
                        systemName: "arrow.clockwise",
                        isEnabled: tabManager.activeTab != nil,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.webView.reload()
                            }
                        }
                    )
                    .oraShortcut(KeyboardShortcuts.Navigation.reload)
                    .oraShortcutHelp("Reload This Page", for: KeyboardShortcuts.Navigation.reload)

                    // URL field
                    HStack(spacing: 8) {
                        // Security indicator
                        if !isEditing {
                            ZStack {
                                if tab.isLoading {
                                    ProgressView()
                                        // .progressViewStyle(CircularProgressViewStyle(tint: getForegroundColor(tab)))
                                        .tint(buttonForegroundColor)
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: tab.url.scheme == "https" ? "lock.fill" : "globe")
                                        .font(.system(size: 12))
                                        .foregroundColor(tab.url.scheme == "https" ? .green : buttonForegroundColor)
                                }
                            }
                            .frame(width: 16, height: 16)
                        }

                        ZStack(alignment: .leading) {
                            TextField("", text: $editingURLString)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isEditing)
                                .onSubmit {
                                    tab.loadURL(editingURLString)
                                    isEditing = false
                                }
                                .opacity(showCopiedAnimation ? 0 : 1)
                                .offset(y: showCopiedAnimation ? (startWheelAnimation ? -12 : 12) : 0)
                                .animation(.easeOut(duration: 0.3), value: showCopiedAnimation)
                                .animation(.easeOut(duration: 0.3), value: startWheelAnimation)

                            CopiedURLOverlay(
                                foregroundColor: getUrlFieldColor(tab),
                                showCopiedAnimation: $showCopiedAnimation,
                                startWheelAnimation: $startWheelAnimation
                            )
                        }
                        .font(.system(size: 14))
                        .foregroundColor(getUrlFieldColor(tab))
                        .onTapGesture {
                            if let activeTab = tabManager.activeTab {
                                editingURLString = activeTab.url.absoluteString
                            }
                            isEditing = true
                        }
                        .onKeyPress(.escape) {
                            isEditing = false
                            return .handled
                        }
                        // Overlay the URL/host when not editing
                        .overlay(
                            Group {
                                if !isEditing, editingURLString.isEmpty {
                                    HStack {
                                        Text(getDisplayURL(tab))
                                            .font(.system(size: 14))
                                            .foregroundColor(getUrlFieldColor(tab))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            if let activeTab = tabManager.activeTab {
                                triggerCopy(activeTab.url.absoluteString)
                            }
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(getUrlFieldColor(tab))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                        .oraShortcutHelp("Copy URL", for: KeyboardShortcuts.Address.copyURL)
                        .accessibilityLabel(Text("Copy URL"))
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(getUrlFieldColor(tab).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        isEditing ? getUrlFieldColor(tab).opacity(0.1) : Color.clear,
                                        lineWidth: 1.2
                                    )
                            )
                    )
                    .overlay(
                        // Hidden button for keyboard shortcut
                        Button("") {
                            isEditing = true
                        }
                        .oraShortcut(KeyboardShortcuts.Address.focus)
                        .opacity(0)
                        .allowsHitTesting(false)
                    )

                    ShareLinkButton(
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        onShare: { sourceView, sourceRect in
                            if let activeTab = tabManager.activeTab {
                                shareCurrentPage(tab: activeTab, sourceView: sourceView, sourceRect: sourceRect)
                            }
                        }
                    )

                    URLBarButton(
                        systemName: "ellipsis",
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            showExtensionsPopup.toggle()
                        }
                    )
                    .popover(isPresented: $showExtensionsPopup, arrowEdge: .bottom) {
                        ExtensionsPopupView()
                    }
                }

                .padding(4)
                .onAppear {
                    editingURLString = getDisplayURL(tab)
                    DispatchQueue.main.async {
                        isEditing = false
                    }
                }
                .onChange(of: tab.url) { _, _ in
                    if !isEditing {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onChange(of: appState.showFullURL) { _, _ in
                    if !isEditing, let tab = tabManager.activeTab {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onChange(of: tabManager.activeTab?.id) { _, _ in
                    if !isEditing, let tab = tabManager.activeTab {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onChange(of: isEditing) { _, newValue in
                    if newValue, let tab = tabManager.activeTab {
                        editingURLString = tab.url.absoluteString
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        }
                    } else if let tab = tabManager.activeTab {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .copyAddressURL)) { _ in
                    if let activeTab = tabManager.activeTab {
                        triggerCopy(activeTab.url.absoluteString)
                    }
                }
                .background(
                    Rectangle()
                        .fill(tab.backgroundColor)
                )
            }
        }
    }
}
