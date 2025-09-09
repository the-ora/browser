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
    @State private var showCopiedAnimation = false
    @State private var startWheelAnimation = false

    init(tab: Tab, editingURLString: Binding<String>) {
        self.tab = tab
        self._editingURLString = editingURLString
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

            // URL input field + copied overlay
            ZStack(alignment: .leading) {
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
                    .opacity(showCopiedAnimation ? 0 : 1)
                    .offset(y: showCopiedAnimation ? (startWheelAnimation ? -12 : 12) : 0)
                    .animation(.easeInOut(duration: 0.3), value: showCopiedAnimation)
                    .animation(.easeInOut(duration: 0.3), value: startWheelAnimation)

                CopiedURLOverlay(
                    foregroundColor: theme.foreground,
                    showCopiedAnimation: $showCopiedAnimation,
                    startWheelAnimation: $startWheelAnimation
                )
            }
            .font(.system(size: 14))
            .foregroundColor(theme.foreground)
            .overlay(
                Group {
                    if !isEditing, editingURLString.isEmpty, !showCopiedAnimation {
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
            // Hidden button for copy shortcut (⇧⌘C)
            .overlay(
                Button("") {
                    triggerCopy(tab.url.absoluteString)
                }
                .keyboardShortcut(KeyboardShortcuts.Address.copyURL)
                .opacity(0)
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
            if newValue {
                editingURLString = tab.url.absoluteString
            } else {
                editingURLString = ""
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyAddressURL)) { _ in
            triggerCopy(tab.url.absoluteString)
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
