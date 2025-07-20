import SwiftUI
import AppKit

// MARK: - URLBar
struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager 
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
            return isEditing ? baseColor : baseColor.opacity(0.5)
        } else {
            // Fallback to black if CIColor conversion fails
            return isEditing ? .black : .black.opacity(0.5)
        }
    }
    
    
    var body: some View {
        if let tab = tabManager.activeTab {
            
            
            HStack(spacing: 12) {
                // Navigation buttons
                HStack(spacing: 8) {
                    NavigationButton(
                        systemName: "sidebar.left",
                        isEnabled: true,
                        foregroundColor: getForegroundColor(tab),
                        action: {
                            withAnimation { // Toggle sidebar visibility
                                onSidebarToggle()
                            }
                        }
                    )
                    
                    NavigationButton(
                        systemName: "chevron.left",
                        isEnabled: tab.webView.canGoBack,
                        foregroundColor: getForegroundColor(tab),
                        action: { tab.webView.goBack() }
                    )
                    
                    NavigationButton(
                        systemName: "chevron.right",
                        isEnabled: tab.webView.canGoForward,
                        foregroundColor: getForegroundColor(tab),
                        action: { tab.webView.goForward() }
                    )
                    
                    NavigationButton(
                        systemName: "arrow.clockwise",
                        isEnabled: true,
                        foregroundColor: getForegroundColor(tab),
                        action: { tab.webView.reload() }
                    )
                }
                
                // URL field
                HStack(spacing: 8) {
                    // Security indicator
                    if !isEditing {
                        ZStack {
                            if tab.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: getForegroundColor(tab)))
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: tab.url.scheme == "https" ? "lock.fill" : "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(tab.url.scheme == "https" ? .green : getForegroundColor(tab))
                            }
                        }
                        .frame(width: 16, height: 16)
                    }
                    
                    TextField("", text: $editingURLString)
                        .font(.system(size: 14))
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(getForegroundColor(tab))
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
                                            .foregroundColor(getForegroundColor(tab))
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(getForegroundColor(tab).opacity(isEditing ? 0.1 : 0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isEditing ? getForegroundColor(tab).opacity(0.5) : Color.clear, lineWidth: 1)
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
            
        }else{
            Text("No selected tab")
        }
    }
    
}
