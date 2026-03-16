import AppKit
import SwiftUI

// MARK: - URLBar

struct URLBar: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sidebarManager: SidebarManager
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode

    @Environment(\.theme) private var theme

    // Display mode state
    @State private var showCopiedAnimation = false
    @State private var startWheelAnimation = false

    // Inline launcher state
    @StateObject private var launcherViewModel = LauncherViewModel()
    @State private var launcherInput = ""
    @FocusState private var isLauncherFocused: Bool
    @State private var mouseHasMoved = false
    @State private var mouseMonitor: Any?
    @State private var suppressInitialSearch = false

    let onSidebarToggle: () -> Void

    private var isEditing: Bool {
        appState.isURLBarEditing
    }

    // MARK: - Helpers

    private func getForegroundColor(_ tab: Tab) -> Color {
        let nsColor = NSColor(tab.backgroundColor)
        if let ciColor = CIColor(color: nsColor) {
            let luminance = 0.299 * ciColor.red + 0.587 * ciColor.green + 0.114 * ciColor.blue
            return luminance < 0.5 ? .white : .black
        } else {
            return .black
        }
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

    // MARK: - Inline Launcher

    private func startEditing() {
        guard !isEditing else { return }
        // Pre-fill input before animation so the text field isn't empty on appear
        if let tab = tabManager.activeTab {
            launcherInput = tab.url.absoluteString
        }
        withAnimation(.easeOut(duration: 0.25)) {
            appState.isURLBarEditing = true
        }
    }

    private func setupInlineLauncher() {
        suppressInitialSearch = true
        if let tab = tabManager.activeTab {
            launcherInput = tab.url.absoluteString
        }
        launcherViewModel.searchEngineService.setTheme(theme)
        launcherViewModel.configure(
            tabManager: tabManager,
            historyManager: historyManager,
            downloadManager: downloadManager,
            appState: appState,
            privacyMode: privacyMode,
            onSubmit: onLauncherSubmit,
            onDismiss: dismissEditing,
            navigateInCurrentTab: true
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isLauncherFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            suppressInitialSearch = false
        }

        mouseHasMoved = false
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
                mouseHasMoved = true
                if let monitor = mouseMonitor {
                    NSEvent.removeMonitor(monitor)
                    mouseMonitor = nil
                }
                return event
            }
        }
    }

    private func cleanupInlineLauncher() {
        isLauncherFocused = false
        launcherInput = ""
        launcherViewModel.suggestions = []
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func dismissEditing() {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.isURLBarEditing = false
        }
    }

    private func onLauncherSubmit(_ newInput: String? = nil) {
        let correctInput = newInput ?? launcherInput

        if let defaultEngine = launcherViewModel.searchEngineService.getDefaultSearchEngine(
            for: tabManager.activeContainer?.id
        ) {
            let customEngine = launcherViewModel.searchEngineService.settings.customSearchEngines
                .first { $0.searchURL == defaultEngine.searchURL }
            let match = defaultEngine.toLauncherMatch(
                originalAlias: correctInput,
                customEngine: customEngine
            )
            if let url = launcherViewModel.searchEngineService.createSearchURL(for: match, query: correctInput) {
                tabManager.activeTab?.loadURL(url.absoluteString)
            }
        }
        dismissEditing()
    }

    // MARK: - Body

    var body: some View {
        if let tab = tabManager.activeTab {
            HStack(spacing: 4) {
                if toolbarManager.isToolbarHidden || sidebarManager.sidebarPosition == .secondary {
                    WindowControls(isFullscreen: appState.isFullscreen)
                }

                if sidebarManager.sidebarPosition == .primary {
                    URLBarButton(
                        systemName: "sidebar.left",
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        action: onSidebarToggle
                    )
                    .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)
                }

                // Back button
                URLBarButton(
                    systemName: "chevron.left",
                    isEnabled: tabManager.activeTab?.canGoBack ?? false,
                    foregroundColor: buttonForegroundColor,
                    action: { tabManager.activeTab?.goBack() }
                )
                .oraShortcut(KeyboardShortcuts.Navigation.back)
                .oraShortcutHelp("Go Back", for: KeyboardShortcuts.Navigation.back)

                // Forward button
                URLBarButton(
                    systemName: "chevron.right",
                    isEnabled: tabManager.activeTab?.canGoForward ?? false,
                    foregroundColor: buttonForegroundColor,
                    action: { tabManager.activeTab?.goForward() }
                )
                .oraShortcut(KeyboardShortcuts.Navigation.forward)
                .oraShortcutHelp("Go Forward", for: KeyboardShortcuts.Navigation.forward)

                // Reload button
                URLBarButton(
                    systemName: "arrow.clockwise",
                    isEnabled: tabManager.activeTab != nil,
                    foregroundColor: buttonForegroundColor,
                    action: { tabManager.activeTab?.reload() }
                )
                .oraShortcut(KeyboardShortcuts.Navigation.reload)
                .oraShortcutHelp("Reload This Page", for: KeyboardShortcuts.Navigation.reload)

                // URL field area - morphs between display and launcher input
                Group {
                    if isEditing {
                        inlineLauncherInput(tab: tab)
                            .transition(.blurReplace)
                    } else {
                        urlDisplayField(tab: tab)
                            .transition(.blurReplace)
                    }
                }
                .overlay(alignment: .top) {
                    if isEditing {
                        suggestionsOverlay()
                            .offset(y: 38)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .zIndex(1)

                URLBarMenuButton(
                    foregroundColor: buttonForegroundColor,
                    onShare: { sourceView, sourceRect in
                        if let activeTab = tabManager.activeTab {
                            shareCurrentPage(tab: activeTab, sourceView: sourceView, sourceRect: sourceRect)
                        }
                    }
                )

                if sidebarManager.sidebarPosition == .secondary {
                    URLBarButton(
                        systemName: "sidebar.right",
                        isEnabled: true,
                        foregroundColor: buttonForegroundColor,
                        action: onSidebarToggle
                    )
                    .oraShortcutHelp("Toggle Sidebar", for: KeyboardShortcuts.App.toggleSidebar)
                }
            }
            .padding(4)
            .background(
                Rectangle()
                    .fill(tab.backgroundColor)
            )
            .animation(.easeOut(duration: 0.25), value: isEditing)
            // Hidden button for keyboard shortcut
            .overlay(
                Button("") { startEditing() }
                    .oraShortcut(KeyboardShortcuts.Address.focus)
                    .opacity(0)
                    .allowsHitTesting(false)
            )
            .onChange(of: tabManager.activeTab?.id) { _, _ in
                if isEditing { dismissEditing() }
            }
            .onChange(of: appState.isURLBarEditing) { _, newValue in
                if newValue {
                    setupInlineLauncher()
                } else {
                    cleanupInlineLauncher()
                }
            }
            .onChange(of: appState.showLauncher) { _, newValue in
                // Dismiss URL bar editing if the center launcher is opened
                if newValue, isEditing { dismissEditing() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copyAddressURL)) { _ in
                if let activeTab = tabManager.activeTab {
                    ClipboardUtils.copyWithToast(
                        activeTab.url.absoluteString,
                        toastManager: toastManager
                    )
                }
            }
        }
    }

    // MARK: - URL Display Field (non-editing)

    private func urlDisplayField(tab: Tab) -> some View {
        HStack(spacing: 8) {
            // Security indicator
            ZStack {
                if tab.isLoading {
                    ProgressView()
                        .tint(buttonForegroundColor)
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: tab.url.scheme == "https" ? "shield.lefthalf.filled" : "globe")
                        .font(.system(size: 12))
                        .foregroundColor(buttonForegroundColor)
                }
            }
            .frame(width: 16, height: 16)

            ZStack(alignment: .leading) {
                CopiedURLOverlay(
                    foregroundColor: buttonForegroundColor,
                    showCopiedAnimation: $showCopiedAnimation,
                    startWheelAnimation: $startWheelAnimation
                )

                // URL display
                let parts = URLDisplayUtils.displayParts(
                    url: tab.url,
                    title: tab.title,
                    showFull: toolbarManager.showFullURL
                )
                HStack(spacing: 0) {
                    Text(parts.host)
                        .font(.system(size: 14))
                        .foregroundColor(buttonForegroundColor)
                    if let title = parts.title {
                        Text(" / \(title)")
                            .font(.system(size: 14))
                            .foregroundColor(buttonForegroundColor.opacity(0.6))
                    }
                    Spacer()
                }
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(showCopiedAnimation ? 0 : 1)
                .offset(y: showCopiedAnimation ? (startWheelAnimation ? -12 : 12) : 0)
                .animation(.easeOut(duration: 0.3), value: showCopiedAnimation)
                .animation(.easeOut(duration: 0.3), value: startWheelAnimation)
            }
            .font(.system(size: 14))
            .foregroundColor(buttonForegroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let activeTab = tabManager.activeTab {
                    triggerCopy(activeTab.url.absoluteString)
                }
            } label: {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(buttonForegroundColor)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .oraShortcutHelp("Copy URL", for: KeyboardShortcuts.Address.copyURL)
            .accessibilityLabel(Text("Copy URL"))
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .background(
            ConditionallyConcentricRectangle(cornerRadius: 10, style: .continuous)
                .fill(buttonForegroundColor.opacity(0.08))
        )
        .contentShape(Rectangle())
        .onTapGesture { startEditing() }
    }

    // MARK: - Inline Launcher Input (editing)

    private func inlineLauncherInput(tab: Tab) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValidURL(launcherInput) ? "globe" : "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(buttonForegroundColor)
                .frame(width: 16, height: 16)

            LauncherTextField(
                text: $launcherInput,
                font: NSFont.systemFont(ofSize: 14, weight: .regular),
                onTab: {},
                onSubmit: {
                    launcherViewModel.executeCommand()
                },
                onDelete: { false },
                onMoveUp: {
                    launcherViewModel.moveFocusedElement(.up)
                },
                onMoveDown: {
                    launcherViewModel.moveFocusedElement(.down)
                },
                cursorColor: getForegroundColor(tab).opacity(0.8),
                textColor: getForegroundColor(tab).opacity(0.7),
                placeholder: "Search the web or enter URL..."
            )
            .textFieldStyle(PlainTextFieldStyle())
            .focused($isLauncherFocused)
            .onChange(of: launcherInput) { _, newValue in
                launcherViewModel.currentText = newValue
                guard !suppressInitialSearch else { return }
                launcherViewModel.searchHandler(newValue)
            }
            .onKeyPress(.escape) {
                dismissEditing()
                return .handled
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ConditionallyConcentricRectangle(cornerRadius: 10, style: .continuous)
                .fill(buttonForegroundColor.opacity(0.08))
                .overlay(
                    ConditionallyConcentricRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            buttonForegroundColor.opacity(0.1),
                            lineWidth: 1.2
                        )
                )
        )
    }

    // MARK: - Suggestions Overlay

    @ViewBuilder
    private func suggestionsOverlay() -> some View {
        if !launcherViewModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(launcherViewModel.suggestions) { suggestion in
                    LauncherSuggestionItem(
                        suggestion: suggestion,
                        focusedElement: $launcherViewModel.focusedElement
                    )
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.launcherMainBackground)
            .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                ConditionallyConcentricRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.foreground.opacity(0.05), lineWidth: 1)
                    .padding(0.25)
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .environment(\.launcherMouseHasMoved, mouseHasMoved)
        }
    }
}
