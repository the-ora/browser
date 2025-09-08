import AppKit
import SwiftData
import SwiftUI

// MARK: - Extensions Popup View

struct ExtensionsPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var tabManager: TabManager

    @State private var locationPermission: PermissionState = .ask
    @State private var cameraPermission: PermissionState = .ask
    @State private var microphonePermission: PermissionState = .ask
    @State private var notificationsPermission: PermissionState = .ask

    enum PermissionState: String, CaseIterable {
        case ask = "Ask"
        case allow = "Allow"
        case block = "Block"

        var next: PermissionState {
            switch self {
            case .ask: return .allow
            case .allow: return .block
            case .block: return .allow
            }
        }
    }

    private var currentHost: String {
        return tabManager.activeTab?.url.host ?? "example.com"
    }

    private func togglePermission(_ kind: PermissionKind, currentState: Binding<PermissionState>) {
        let newState = currentState.wrappedValue.next
        currentState.wrappedValue = newState

        // Update SwiftData
        updateSitePermission(for: kind, allow: newState == .allow)
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
        case .location:
            site.locationAllowed = allow
            site.locationConfigured = true
        case .camera:
            site.cameraAllowed = allow
            site.cameraConfigured = true
        case .microphone:
            site.microphoneAllowed = allow
            site.microphoneConfigured = true
        case .notifications:
            site.notificationsAllowed = allow
            site.notificationsConfigured = true
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
            locationPermission = site.locationConfigured ? (site.locationAllowed ? .allow : .block) : .ask
            cameraPermission = site.cameraConfigured ? (site.cameraAllowed ? .allow : .block) : .ask
            microphonePermission = site.microphoneConfigured ? (site.microphoneAllowed ? .allow : .block) : .ask
            notificationsPermission = site
                .notificationsConfigured ? (site.notificationsAllowed ? .allow : .block) : .ask
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Settings section
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.primary)

                Button(action: { togglePermission(.location, currentState: $locationPermission) }) {
                    PopupPermissionRow(icon: "location", title: "Location", status: locationPermission.rawValue)
                }
                .buttonStyle(.plain)

                Button(action: { togglePermission(.camera, currentState: $cameraPermission) }) {
                    PopupPermissionRow(icon: "camera", title: "Camera", status: cameraPermission.rawValue)
                }
                .buttonStyle(.plain)

                Button(action: { togglePermission(.microphone, currentState: $microphonePermission) }) {
                    PopupPermissionRow(icon: "mic", title: "Microphone", status: microphonePermission.rawValue)
                }
                .buttonStyle(.plain)

                Button(action: { togglePermission(.notifications, currentState: $notificationsPermission) }) {
                    PopupPermissionRow(icon: "bell", title: "Notifications", status: notificationsPermission.rawValue)
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

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    var buttonForegroundColor: Color {
        return tabManager.activeTab.map { getForegroundColor($0).opacity(0.5) } ?? .gray
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
        HStack(spacing: 12) {
            // Navigation buttons
            if let tab = tabManager.activeTab {
                HStack(spacing: 8) {
                    // Sidebar button, always shown with fallback color if no active tab
                    NavigationButton(
                        systemName: "sidebar.left",
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        action: onSidebarToggle
                    )
                    .keyboardShortcut(KeyboardShortcuts.App.toggleSidebar)

                    // Back button
                    NavigationButton(
                        systemName: "chevron.left",
                        isEnabled: tabManager.activeTab?.webView.canGoBack ?? false,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goBack()
                            }
                        }
                    )
                    .keyboardShortcut(KeyboardShortcuts.Navigation.back)

                    // Forward button
                    NavigationButton(
                        systemName: "chevron.right",
                        isEnabled: tabManager.activeTab?.webView.canGoForward ?? false,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.goForward()
                            }
                        }
                    )
                    .keyboardShortcut(KeyboardShortcuts.Navigation.forward)

                    // Reload button
                    NavigationButton(
                        systemName: "arrow.clockwise",
                        isEnabled: tabManager.activeTab != nil,
                        foregroundColor: buttonForegroundColor,
                        action: {
                            if let activeTab = tabManager.activeTab {
                                activeTab.webView.reload()
                            }
                        }
                    )
                    .keyboardShortcut(KeyboardShortcuts.Navigation.reload)

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
                                .animation(.easeInOut(duration: 0.3), value: showCopiedAnimation)
                                .animation(.easeInOut(duration: 0.3), value: startWheelAnimation)

                            HStack {
                                Image(systemName: "link")

                                Text("Copied Current URL")
                            }
                            .opacity(showCopiedAnimation ? 1 : 0)
                            .offset(y: showCopiedAnimation ? 0 : (startWheelAnimation ? -12 : 12))
                            .animation(.easeInOut(duration: 0.3), value: showCopiedAnimation)
                            .animation(.easeInOut(duration: 0.3), value: startWheelAnimation)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(getUrlFieldColor(tab))
                        .onTapGesture {
                            editingURLString = tab.url.absoluteString
                        }
                        .onKeyPress(.escape) {
                            isEditing = false
                            return .handled
                        }
                        // Overlay the placeholder when not editing
                        .overlay(
                            Group {
                                if !isEditing, editingURLString.isEmpty {
                                    HStack {
                                        Text(tab.title.isEmpty ? "New Tab" : tab.title)
                                            .font(.system(size: 14))
                                            .foregroundColor(getUrlFieldColor(tab))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                }
                            }
                        )
                        // Hidden button for copy shortcut
                        .overlay(
                            Button("") {
                                copyToClipboard(tab.url.absoluteString)
                                withAnimation {
                                    showCopiedAnimation = true
                                    startWheelAnimation = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    withAnimation {
                                        showCopiedAnimation = false
                                        startWheelAnimation = false
                                    }
                                }
                            }
                            .keyboardShortcut(KeyboardShortcuts.Address.copyURL)
                            .opacity(0)
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(getUrlFieldColor(tab).opacity(isEditing ? 0.1 : 0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isEditing ? getUrlFieldColor(tab).opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    )
                    .overlay(
                        // Hidden button for keyboard shortcut
                        Button("") {
                            isEditing = true
                        }
                        .keyboardShortcut(KeyboardShortcuts.Address.focus)
                        .opacity(0)
                    )

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        ShareButton(
                            foregroundColor: buttonForegroundColor,
                            onShare: { sourceView, sourceRect in
                                if let activeTab = tabManager.activeTab {
                                    shareCurrentPage(tab: activeTab, sourceView: sourceView, sourceRect: sourceRect)
                                }
                            }
                        )
                        .frame(width: 32, height: 32)

                        NavigationButton(
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                //            .onReceive(tab.$url) { newURL in
                //                if !isEditing {
                //                    editingURLString = newURL.absoluteString
                //                }
                //            }
                .onAppear {
                    editingURLString = tab.url.absoluteString
                    DispatchQueue.main.async {
                        isEditing = false
                    }
                }
                .onChange(of: tab.url) { _, newValue in
                    if !isEditing {
                        editingURLString = newValue.absoluteString
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

struct ShareButton: NSViewRepresentable {
    let foregroundColor: Color
    let onShare: (NSView, NSRect) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonTapped)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.onShare = onShare
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onShare: onShare)
    }

    class Coordinator: NSObject {
        var onShare: (NSView, NSRect) -> Void

        init(onShare: @escaping (NSView, NSRect) -> Void) {
            self.onShare = onShare
        }

        @objc func buttonTapped(_ sender: NSButton) {
            let rect = sender.bounds
            onShare(sender, rect)
        }
    }
}
