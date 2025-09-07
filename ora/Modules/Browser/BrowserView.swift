import AppKit
import SwiftUI

// MARK: - BrowserView

struct BrowserView: View {
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.theme) var theme
    @EnvironmentObject private var appState: AppState
    @State private var isFullscreen = false
    @State private var showFloatingSidebar = false

    @StateObject var hide = SideHolder()

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Ora \(version)"
    }

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            hide.toggle(.primary)
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
                        BrowserContentContainer(isFullscreen: isFullscreen, hideState: hide) {
                            webView
                        }
                    } else {
                        // Start page (visible when no tab is active)
                        BrowserContentContainer(isFullscreen: isFullscreen, hideState: hide) {
                            ZStack(alignment: .top) {
                                Color.clear
                                    .ignoresSafeArea(.all)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .background(theme.background.opacity(0.65))
                                    .background(
                                        BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                                    )

                                NavigationButton(
                                    systemName: "sidebar.left",
                                    isEnabled: true,
                                    foregroundColor: theme.foreground.opacity(0.3),
                                    action: { toggleSidebar() }
                                )
                                .position(x: 24, y: 24)
                                .zIndex(3)

                                VStack(alignment: .center, spacing: 16) {
                                    Image("ora-logo-plain")
                                        .resizable()
                                        .renderingMode(.template)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(theme.foreground.opacity(0.3))

                                    Text("Less noise, more browsing.")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(theme.foreground.opacity(0.3))
                                }
                                .offset(x: -10, y: 120)
                                .zIndex(2)

                                LauncherView(clearOverlay: true)
                            }
                        }
                    }
                }
            )
            .hide(hide)
            .splitter { Splitter.invisible() }
            .fraction(0.2)
            .constraints(
                minPFraction: 0.15,
                minSFraction: 0.7,
                priority: .left,
                dragToHideP: true
            )
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
                    isSidebarHidden: hide.side == .primary,
                    isFloatingSidebar: showFloatingSidebar,
                    isFullscreen: $isFullscreen
                )
            )
            .overlay {
                if appState.showLauncher, tabManager.activeTab != nil {
                    LauncherView()
                }

                if appState.isFloatingTabSwitchVisible {
                    FloatingTabSwitcher()
                }
            }

            if hide.side == .primary {
                if showFloatingSidebar {
                    FloatingSidebar(isFullscreen: isFullscreen)
                        .frame(width: 340)
                        .transition(.move(edge: .leading))
                        .zIndex(3)
                }

                Color.clear
                    .frame(width: showFloatingSidebar ? 340 : 10)
                    .overlay(
                        MouseTrackingArea(mouseEntered: $showFloatingSidebar, xExit: 340)
                    )
                    .zIndex(2)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: showFloatingSidebar)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            toggleSidebar()
        }
    }

    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !appState.isToolbarHidden {
                URLBar(
                    onSidebarToggle: { toggleSidebar() }
                )
            }
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

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    let content: () -> Content
    let isFullscreen: Bool
    let hideState: SideHolder

    init(isFullscreen: Bool, hideState: SideHolder, @ViewBuilder content: @escaping () -> Content) {
        self.isFullscreen = isFullscreen
        self.hideState = hideState
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            content()
                .overlay {
                    VStack(alignment: .leading, spacing: 0) {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "FF5F57").opacity(0.3),
                                Color(hex: "FF5F57").opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(
                            width: geometry.size.width
                                * CGFloat((tabManager.activeTab?.loadingProgress ?? 10) / 100), height: 12
                        )
                        .blur(radius: 12)
                        .animation(.easeOut(duration: 0.3), value: tabManager.activeTab?.loadingProgress)

                        Color.red
                            .frame(
                                width: geometry.size.width
                                    * CGFloat((tabManager.activeTab?.loadingProgress ?? 10) / 100),
                                height: 1.5
                            )
                            .cornerRadius(8)
                            .offset(y: -12)  // Overlap slightly with the gradient
                            .animation(.easeOut(duration: 0.3), value: tabManager.activeTab?.loadingProgress)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: isFullscreen && hideState.side == .primary ? 0 : 9, style: .continuous
                        )
                    )
                    .opacity(tabManager.activeTab?.isLoading == true ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.3).delay(tabManager.activeTab?.isLoading == true ? 0 : 0.5),
                        value: tabManager.activeTab?.isLoading
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(isFullscreen && hideState.side == .primary ? 0 : 8)
        .padding(
            isFullscreen && hideState.side == .primary
                ? EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )
                : EdgeInsets(
                    top: 10,
                    leading: hideState.side == .primary ? 10 : 0,
                    bottom: 10,
                    trailing: 10
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .ignoresSafeArea(.all)
    }
}
