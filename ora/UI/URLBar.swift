import SwiftUI
import AppKit

// MARK: - URLBar
struct URLBar: View {
    @ObservedObject var tab: BrowserTab
    @Binding var columnVisibility: NavigationSplitViewVisibility // Add binding for column visibility
    @State private var editingURLString: String = ""
    @State private var isEditing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 8) {
                NavigationButton(
                    systemName: "sidebar.left",
                    isEnabled: true,
                    action: {
                        withAnimation { // Toggle sidebar visibility
                            columnVisibility = (columnVisibility == .all) ? .detailOnly : .all
                        }
                    }
                )
                
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
                                        .foregroundColor(Color(colorScheme == .dark ? .white : .black))
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
                    .fill(Color(tab.themeColor ?? .black))
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
        .padding(.vertical, 6)
        .onReceive(tab.$url) { newURL in
            if !isEditing {
                editingURLString = newURL.absoluteString
            }
        }
        .onAppear {
            editingURLString = tab.url.absoluteString
        }
        .background(
            Rectangle()
                .fill(Color(tab.themeColor ?? .black))
        )
    }
}