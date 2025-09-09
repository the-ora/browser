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

    var buttonForegroundColor: Color {
        return tabManager.activeTab.map { getForegroundColor($0).opacity(0.5) } ?? .gray
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
                        // Share current page (uses macOS share sheet like Safari)
                        ShareLink(item: tab.url, preview: SharePreview(tab.title)) {
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
