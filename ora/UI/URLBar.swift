import AppKit
import SwiftUI
import WebKit

struct ExtensionIconView: NSViewRepresentable {
    let iconName: String
    let tooltip: String

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.toolTip = tooltip
        imageView.isEditable = false
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.toolTip = tooltip
    }
}

struct ExtensionIconButton: NSViewRepresentable {
    let ext: WKWebExtension
    let extensionManager: OraExtensionManager

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.image = ext.icon(for: NSSize(width: 32, height: 32))
        button.imageScaling = .scaleProportionallyUpOrDown
        button.toolTip = ext.displayName ?? "Extension"
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.image = ext.icon(for: NSSize(width: 32, height: 32))
        nsView.toolTip = ext.displayName ?? "Extension"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(ext: ext, extensionManager: extensionManager)
    }

    class Coordinator: NSObject {
        let ext: WKWebExtension
        let extensionManager: OraExtensionManager

        init(ext: WKWebExtension, extensionManager: OraExtensionManager) {
            self.ext = ext
            self.extensionManager = extensionManager
        }

        @objc func clicked(_ sender: NSButton) {
            guard let context = extensionManager.controller.extensionContexts.first(where: { $0.webExtension == ext }),
                  let action = context.action(for: nil), action.presentsPopup,
                  let popover = action.popupPopover
            else {
                print("No popup for extension: \(ext.displayName ?? "Unknown")")
                return
            }
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.maxY)
        }
    }
}

// MARK: - URLBar

struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var extensionManager: OraExtensionManager

    @State private var showCopiedAnimation = false
    @State private var startWheelAnimation = false
    @State private var editingURLString: String = ""
    @FocusState private var isEditing: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var alertMessage: String?

    let onSidebarToggle: () -> Void
    let size: CGSize = .init(width: 32, height: 32)

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

    private var extensionIconsView: some View {
        HStack(spacing: 4) {
            ForEach(extensionManager.installedExtensions, id: \.self) { ext in
                ExtensionIconButton(ext: ext, extensionManager: extensionManager)
                    .frame(width: size.width, height: size.height)
            }
        }
        .padding(.horizontal, 4)
        .alert("Notice", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        }, message: {
            if let message = alertMessage {
                Text(message)
            }
        })
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

                    // Extension icons
                    if !extensionManager.installedExtensions.isEmpty {
                        extensionIconsView
                    }

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
                        action: {}
                    )
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
