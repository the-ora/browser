import AppKit
import SwiftUI

enum SidebarPosition {
    case primary
    case secondary
}

struct BrowserView: View {
    @Environment(\.theme) var theme
    @Environment(\.window) var window: NSWindow?
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var privacyMode: PrivacyMode

    @State private var isFullscreen = false
    @State private var showFloatingSidebar = false
    @State private var isMouseOverSidebar = false

    @StateObject private var sidebarFraction = FractionHolder.usingUserDefaults(0.2, key: "ui.sidebar.fraction")
    @State private var sidebarPosition: SidebarPosition = .primary
    @StateObject private var sidebarVisibility = SideHolder.usingUserDefaults(key: "ui.sidebar.visibility")

    // MARK: - Derived state

    private var targetSide: SplitSide {
        sidebarPosition == .primary ? .primary : .secondary
    }

    private var isSidebarHidden: Bool {
        sidebarVisibility.side == targetSide
    }

    private var fractionValue: CGFloat {
        sidebarPosition == .primary ? 0.2 : 0.8
    }

    private var minPF: CGFloat {
        sidebarPosition == .primary ? 0.16 : 0.7
    }

    private var minSF: CGFloat {
        sidebarPosition == .primary ? 0.7 : 0.16
    }

    private var prioritySide: SplitSide {
        sidebarPosition == .primary ? .primary : .secondary
    }

    private var dragToHidePFlag: Bool {
        sidebarPosition == .primary
    }

    private var dragToHideSFlag: Bool {
        sidebarPosition == .secondary
    }

    // MARK: - Actions

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            sidebarVisibility.side =
                (sidebarVisibility.side == targetSide) ? nil : targetSide
        }
    }

    private func toggleSidebarPosition() {
        let wasHidden = isSidebarHidden
        sidebarPosition =
            (sidebarPosition == .primary) ? .secondary : .primary
        if wasHidden {
            sidebarVisibility.side = targetSide
        }
    }

    private func toggleMaximizeWindow() {
        window?.toggleMaximized()
    }

    // MARK: - Pane Builders

    @ViewBuilder
    private func primaryPane() -> some View {
        if sidebarPosition == .primary {
            if sidebarVisibility.side == .primary {
                contentView()
            } else {
                SidebarView(isFullscreen: isFullscreen)
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func secondaryPane() -> some View {
        if sidebarPosition == .secondary {
            if sidebarVisibility.side == .secondary {
                contentView()
            } else {
                SidebarView(isFullscreen: isFullscreen)
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        if tabManager.activeTab != nil {
            BrowserContentContainer(
                isFullscreen: isFullscreen,
                hideState: sidebarVisibility,
                sidebarPosition: sidebarPosition
            ) { webView }
        } else {
            BrowserContentContainer(
                isFullscreen: isFullscreen,
                hideState: sidebarVisibility,
                sidebarPosition: sidebarPosition
            ) {
                HomeView(sidebarToggle: toggleSidebar)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            HSplit(left: { primaryPane() }, right: { secondaryPane() })
                .hide(sidebarVisibility)
                .splitter { Splitter.invisible() }
                .fraction(fractionValue)
                .constraints(
                    minPFraction: minPF,
                    minSFraction: minSF,
                    priority: prioritySide,
                    dragToHideP: dragToHidePFlag,
                    dragToHideS: dragToHideSFlag
                )
                .styling(hideSplitter: true)
                .ignoresSafeArea(.all)
                .background(theme.subtleWindowBackgroundColor)
                .background(
                    BlurEffectView(
                        material: .underWindowBackground,
                        blendingMode: .behindWindow
                    ).ignoresSafeArea(.all)
                )
                .background(
                    WindowAccessor(
                        isSidebarHidden: sidebarVisibility.side == .primary
                            || sidebarVisibility.side == .secondary,
                        isFloatingSidebar: $showFloatingSidebar,
                        isFullscreen: $isFullscreen
                    )
                    .id("showFloatingSidebar = \(showFloatingSidebar)")
                )
                .overlay {
                    if appState.showLauncher, tabManager.activeTab != nil {
                        LauncherView()
                    }
                    if appState.isFloatingTabSwitchVisible {
                        FloatingTabSwitcher()
                    }
                }

            // Floating sidebar overlay
            if sidebarVisibility.side == .primary || sidebarVisibility.side == .secondary {
                floatingSidebarOverlay()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarPosition)) { _ in
            toggleSidebarPosition()
        }
        .onChange(of: downloadManager.isDownloadsPopoverOpen) { _, isOpen in
            if sidebarVisibility.side == .primary || sidebarVisibility.side == .secondary {
                if isOpen {
                    showFloatingSidebar = true
                } else if !isMouseOverSidebar {
                    showFloatingSidebar = false
                }
            }
        }
        .onChange(of: tabManager.activeTab) { _, newTab in
            if let tab = newTab, !tab.isWebViewReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    tab.restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            }
        }
        .onTapGesture(count: 2) {
            toggleMaximizeWindow()
        }
        .onAppear {
            // Restore active tab on app startup if not already ready
            if let tab = tabManager.activeTab, !tab.isWebViewReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tab.restoreTransientState(
                        historyManger: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            }
        }
    }

    // MARK: - Floating Sidebar

    @ViewBuilder
    private func floatingSidebarOverlay() -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let minFraction: CGFloat = 0.16
            let maxFraction: CGFloat = 0.30
            let clampedFraction =
                min(max(sidebarFraction.value, minFraction), maxFraction)
            let floatingWidth = max(0, min(totalWidth * clampedFraction, totalWidth))

            ZStack(alignment: .leading) {
                if showFloatingSidebar {
                    FloatingSidebar(isFullscreen: isFullscreen)
                        .frame(width: floatingWidth)
                        .transition(.move(edge: .leading))
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 14)
                            #if targetEnvironment(macCatalyst) || os(macOS)
                                .cursor(NSCursor.resizeLeftRight)
                            #endif
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let proposedWidth = max(
                                                0,
                                                min(
                                                    floatingWidth + value.translation.width,
                                                    totalWidth
                                                )
                                            )
                                            let newFraction =
                                                proposedWidth / max(totalWidth, 1)
                                            sidebarFraction.value =
                                                min(max(newFraction, minFraction), maxFraction)
                                        }
                                )
                        }
                        .zIndex(3)
                }

                // Hover strip
                Color.clear
                    .frame(width: showFloatingSidebar ? floatingWidth : 10)
                    .overlay(
                        MouseTrackingArea(
                            mouseEntered: Binding(
                                get: { showFloatingSidebar },
                                set: { newValue in
                                    isMouseOverSidebar = newValue
                                    if !newValue, downloadManager.isDownloadsPopoverOpen {
                                        return
                                    }
                                    showFloatingSidebar = newValue
                                }
                            )
                        )
                    )
                    .zIndex(2)
            }
        }
    }

    // MARK: - WebView content

    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !appState.isToolbarHidden {
                URLBar(
                    onSidebarToggle: { toggleSidebar() },
                    sidebarPosition: sidebarPosition
                )
                .transition(.asymmetric(
                    insertion: .push(from: .top),
                    removal: .push(from: .bottom)
                ))
            }

            if let tab = tabManager.activeTab {
                if tab.isWebViewReady {
                    if tab.hasNavigationError, let error = tab.navigationError {
                        StatusPageView(
                            error: error,
                            failedURL: tab.failedURL,
                            onRetry: { tab.retryNavigation() },
                            onGoBack: tab.webView.canGoBack ? {
                                tab.webView.goBack()
                                tab.clearNavigationError()
                            } : nil
                        )
                        .id(tab.id)
                    } else {
                        ZStack(alignment: .topTrailing) {
                            WebView(webView: tab.webView).id(tab.id)

                            if appState.showFinderIn == tab.id {
                                FindView(webView: tab.webView)
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                                    .zIndex(1000)
                            }

                            if let hovered = tab.hoveredLinkURL, !hovered.isEmpty {
                                LinkPreview(text: hovered)
                            }
                        }
                    }
                } else {
                    ZStack {
                        Rectangle().fill(theme.background)
                        ProgressView().frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
