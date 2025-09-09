import AppKit
import SwiftUI

// MARK: - URLBar

struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState

    @State private var showCopiedAnimation = false
    @State private var startWheelAnimation = false
    @State private var editingURLString: String = ""
    @FocusState private var isEditing: Bool
    @Environment(\.colorScheme) var colorScheme

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

    private func triggerCopy(_ text: String) {
        // Prevent double-trigger if both Command and view shortcut fire
        if showCopiedAnimation { return }
        copyToClipboard(text)
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
                            CopiedURLOverlay(
                                foregroundColor: getUrlFieldColor(tab),
                                showCopiedAnimation: $showCopiedAnimation,
                                startWheelAnimation: $startWheelAnimation
                            )
                        }
                        .font(.system(size: 14))
                        .foregroundColor(getUrlFieldColor(tab))
                        .onTapGesture {
                            editingURLString = tab.url.absoluteString
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
                            triggerCopy(tab.url.absoluteString)
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(getUrlFieldColor(tab))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                        .help("Copy URL (⇧⌘C)")
                        .accessibilityLabel(Text("Copy URL"))
                        .keyboardShortcut(KeyboardShortcuts.Address.copyURL)
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
                        .allowsHitTesting(false)
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
                            action: {}
                        )
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
                .contextMenu {
                    if appState.showFullURL {
                        Button(action: {
                            appState.showFullURL = false
                        }) {
                            Label("Hide Full URL", systemImage: "eye.slash")
                        }
                    } else {
                        Button(action: {
                            appState.showFullURL = true
                        }) {
                            Label("Show Full URL", systemImage: "eye")
                        }
                    }

                    Divider()

                    if appState.isToolbarHidden {
                        Button(action: {
                            appState.isToolbarHidden = false
                        }) {
                            Label("Show Toolbar", systemImage: "eye")
                        }
                    } else {
                        Button(action: {
                            appState.isToolbarHidden = true
                        }) {
                            Label("Hide Toolbar", systemImage: "eye.slash")
                        }
                    }
                }
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
