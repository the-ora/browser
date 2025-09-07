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

    init(tab: Tab, editingURLString: Binding<String>) {
        self.tab = tab
        self._editingURLString = editingURLString
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
                    .allowsHitTesting(false)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
            editingURLString = tab.url.absoluteString
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.mutedBackground)
        )
        .padding(.horizontal, 10) // Fixed spacing: outer margin after background
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
        .onAppear {
            // Keep field empty when not editing so overlay shows current URL/host
            editingURLString = ""
            DispatchQueue.main.async {
                isEditing = false
            }
        }
        .onChange(of: tab.url) { _, _ in
            // When the tab's URL changes and we're not editing, keep the field empty
            if !isEditing { editingURLString = "" }
        }
        .onChange(of: appState.showFullURL) { _, _ in
            // Reflect toggle immediately via overlay; keep field empty
            if !isEditing { editingURLString = "" }
        }
        .onChange(of: isEditing) { _, newValue in
            // Populate field when entering edit mode, clear when exiting
            if newValue {
                editingURLString = tab.url.absoluteString
            } else {
                editingURLString = ""
            }
        }
    }

    private func getDisplayURL() -> String {
        if appState.showFullURL {
            return tab.url.absoluteString
        } else {
            return tab.url.host ?? tab.url.absoluteString
        }
    }
}
