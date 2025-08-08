import SwiftUI
import AppKit

// MARK: - URLBar
struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    
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
                        
                        TextField("", text: $editingURLString)
                            .font(.system(size: 14))
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(getUrlFieldColor(tab))
                            .focused($isEditing)
                            .onSubmit {
                                tab.loadURL(editingURLString)
                                isEditing = false
                            }
                            .onTapGesture {
                                editingURLString = tab.url.absoluteString
                            }
                            .overlay(
                                Group {
                                    if !isEditing && editingURLString.isEmpty {
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
