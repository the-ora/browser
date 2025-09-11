import AppKit
import SwiftUI

// MARK: - BrowserView

struct BrowserView: View {
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.theme) var theme
    @EnvironmentObject private var appState: AppState
    @State private var isFullscreen = false
    @State private var showFloatingSidebar = false
    @StateObject private var sidebarFraction = FractionHolder.usingUserDefaults(0.2, key: "ui.sidebar.fraction")

    @StateObject var sidebarVisibility = SideHolder()

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Ora \(version)"
    }

    func sidebarToggle() {
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
                            HomeView(sidebarToggle: sidebarToggle)
                        }
                    }
                }
            )
            .hide(sidebarVisibility)
            .splitter { Splitter.invisible() }
            .fraction(sidebarFraction)
            .constraints(
                minPFraction: 0.15,
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
                    let minFraction: CGFloat = 0.15
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
                                    mouseEntered: $showFloatingSidebar,
                                    xExit: floatingWidth
                                )
                            )
                            .zIndex(2)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
    }

    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            URLBar(
                onSidebarToggle: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
                        sidebarVisibility.toggle(.primary)  // Toggle sidebar with Cmd+S
                    }
                }
            )
            if let tab = tabManager.activeTab {
                if tab.isWebViewReady {
                    if tab.hasNavigationError, let error = tab.navigationError {
                        // Show status page for navigation errors
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
                        // Show normal web view
                        ZStack(alignment: .topTrailing) {
                            WebView(webView: tab.webView)
                                .id(tab.id)

                            // Floating find view overlay
                            if appState.showFinderIn == tab.id {
                                FindView(webView: tab.webView)
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                                    .zIndex(1000)
                            }

                            // Hovered link URL overlay (bottom-left)
                            if let hovered = tab.hoveredLinkURL, !hovered.isEmpty {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(hovered)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(theme.foreground)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .multilineTextAlignment(.leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(theme.background)
                                            )
                                            .background(BlurEffectView(
                                                material: .popover,
                                                blendingMode: .withinWindow
                                            ))
                                            .cornerRadius(99)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 99, style: .continuous)
                                                    .stroke(Color(.separatorColor), lineWidth: 1)
                                            )
                                            .padding(.leading, 12)
                                        Spacer()

                                        // Version indicator (bottom-right)
                                        Text(getAppVersion())
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(Color.black.opacity(0.2))
                                            )
                                            .padding(.trailing, 12)
                                    }
                                    .padding(.bottom, 12)
                                }
                                .transition(.opacity)
                                .animation(.easeOut(duration: 0.1), value: tab.hoveredLinkURL)
                                .zIndex(900)
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
