import AppKit
import SwiftData
import SwiftUI

struct SidebarURLDisplay: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState

    let tab: Tab
    @Binding var editingURLString: String
    @FocusState private var isEditing: Bool
    @Binding var showFullURL: Bool

    init(tab: Tab, editingURLString: Binding<String>, showFullURL: Binding<Bool>) {
        self.tab = tab
        self._editingURLString = editingURLString
        self._showFullURL = showFullURL
    }

    var body: some View {
        HStack(spacing: 8) {
            // Security indicator
            ZStack {
                if tab.isLoading {
                    ProgressView()
                        .tint(theme.foreground.opacity(0.7))
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: tab.url.scheme == "https" ? "lock.fill" : "globe")
                        .font(.system(size: 12))
                        .foregroundColor(tab.url.scheme == "https" ? .green : theme.foreground.opacity(0.7))
                }
            }
            .frame(width: 16, height: 16)

            // URL input field
            TextField("", text: $editingURLString)
                .font(.system(size: 14))
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(theme.foreground)
                .focused($isEditing)
                .onSubmit {
                    tab.loadURL(editingURLString)
                    isEditing = false
                }
                .onTapGesture {
                    editingURLString = tab.url.absoluteString
                    isEditing = true
                }
                .onKeyPress(.escape) {
                    isEditing = false
                    return .handled
                }
                .overlay(
                    Group {
                        if !isEditing, editingURLString.isEmpty {
                            HStack {
                                Text(getDisplayURL())
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.foreground)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                        }
                    }
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.mutedBackground)
        )
        .padding(.horizontal, 10) // Fixed spacing: outer margin after background
        .contextMenu {
            if showFullURL {
                Button(action: {
                    showFullURL = false
                }) {
                    Label("Hide Full URL", systemImage: "eye.slash")
                }
            } else {
                Button(action: {
                    showFullURL = true
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
        .onAppear {
            editingURLString = getDisplayURL()
            DispatchQueue.main.async {
                isEditing = false
            }
        }
        .onChange(of: tab.url) { _, _ in
            if !isEditing {
                editingURLString = getDisplayURL()
            }
        }
        .onChange(of: showFullURL) { _, _ in
            if !isEditing {
                editingURLString = getDisplayURL()
            }
        }
        .onChange(of: tabManager.activeTab?.id) { _, _ in
            if !isEditing {
                editingURLString = getDisplayURL()
            }
        }
    }

    private func getDisplayURL() -> String {
        if showFullURL {
            return tab.url.absoluteString
        } else {
            return tab.url.host ?? tab.url.absoluteString
        }
    }
}
