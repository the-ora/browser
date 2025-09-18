import AppKit
import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.theme) var theme
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var privacyMode: PrivacyMode
    @State private var isFullscreen = false
    @State private var showFloatingSidebar = false
    @State private var isMouseOverSidebar = false
    @StateObject private var sidebarFraction = FractionHolder.usingUserDefaults(0.2, key: "ui.sidebar.fraction")

    @StateObject var sidebarVisibility = SideHolder()

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            sidebarVisibility.toggle(.primary)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HSplit(
                left: {
                    SidebarView(isFullscreen: isFullscreen)
                },
                right: {
                    if tabManager.activeTab != nil {
                        BrowserContentContainer(isFullscreen: isFullscreen, hideState: sidebarVisibility) {
                            webView
                        }
                    } else {
                        // Start page (visible when no tab is active)
                        BrowserContentContainer(isFullscreen: isFullscreen, hideState: sidebarVisibility) {
                            HomeView(sidebarToggle: toggleSidebar)
                        }
                    }
                }
            )
            .hide(sidebarVisibility)
            .splitter { Splitter.invisible() }
            .fraction(sidebarFraction)
            .constraints(
                minPFraction: 0.16,
                minSFraction: 0.7,
                priority: .left,
                dragToHideP: true
            )
            // In autohide mode, remove any draggable splitter area to unhide
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
                    isSidebarHidden: sidebarVisibility.side == .primary,
                    isFloatingSidebar: $showFloatingSidebar,
                    isFullscreen: $isFullscreen
                )
                .id("showFloatingSidebar = \(showFloatingSidebar)") // Forces WindowAccessor to update (for Traffic
                // Lights)
            )
            .overlay {
                if appState.showLauncher, tabManager.activeTab != nil {
                    LauncherView()
                }

                if appState.isFloatingTabSwitchVisible {
                    FloatingTabSwitcher()
                }
            }

            if sidebarVisibility.side == .primary {
                // Floating sidebar with resizable width based on persisted fraction
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let minFraction: CGFloat = 0.16
                    let maxFraction: CGFloat = 0.30
                    let clampedFraction = min(max(sidebarFraction.value, minFraction), maxFraction)
                    let floatingWidth = max(0, min(totalWidth * clampedFraction, totalWidth))
                    ZStack(alignment: .leading) {
                        if showFloatingSidebar {
                            FloatingSidebar(isFullscreen: isFullscreen)
                                .frame(width: floatingWidth)
                                .transition(.move(edge: .leading))
                                .overlay(alignment: .trailing) {
                                    // Invisible resize handle to adjust width in autohide mode
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
                                                        min(floatingWidth + value.translation.width, totalWidth)
                                                    )
                                                    let newFraction = proposedWidth / max(totalWidth, 1)
                                                    // Clamp to same constraints as HSplit
                                                    sidebarFraction.value = min(
                                                        max(newFraction, minFraction),
                                                        maxFraction
                                                    )
                                                }
                                        )
                                }
                                .zIndex(3)
                        }
                        // Hover tracking strip to show/hide floating sidebar
                        Color.clear
                            .frame(width: showFloatingSidebar ? floatingWidth : 10)
                            .overlay(
                                MouseTrackingArea(
                                    mouseEntered: Binding(
                                        get: { showFloatingSidebar },
                                        set: { newValue in
                                            isMouseOverSidebar = newValue
                                            // Don't hide sidebar if downloads popover is open
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
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            toggleSidebar()
        }
        .onChange(of: downloadManager.isDownloadsPopoverOpen) { isOpen in
            if sidebarVisibility.side == .primary {
                if isOpen {
                    // Keep sidebar visible while downloads popover is open
                    showFloatingSidebar = true
                } else if !isMouseOverSidebar {
                    // Hide sidebar when popover closes and mouse is not over sidebar
                    showFloatingSidebar = false
                }
            }
        }
        .onChange(of: tabManager.activeTab) { newTab in
            // Restore tab state when switching tabs via keyboard shortcut
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
    }

    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !appState.isToolbarHidden {
                URLBar(
                    onSidebarToggle: { toggleSidebar() }
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
                            onRetry: {
                                tab.retryNavigation()
                            },
                            onGoBack: tab.webView.canGoBack
                                ? {
                                    tab.webView.goBack()
                                    tab.clearNavigationError()
                                } : nil
                        )
                        .id(tab.id)
                    } else {
                        ZStack(alignment: .topTrailing) {
                            WebView(webView: tab.webView)
                                .id(tab.id)

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
                        Rectangle()
                            .fill(theme.background)

                        ProgressView().frame(width: 32, height: 32)

                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
