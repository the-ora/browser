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

    var body: some View {
        ZStack(alignment: .leading) {
            HSplit(
                left: {
                    SidebarView(isFullscreen: isFullscreen)
                },
                right: {
                    if tabManager.activeTab != nil {
                        webView
                    } else {
                        LauncherView()
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
                if appState.showLauncher && tabManager.activeTab != nil {
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
                    .frame(width: showFloatingSidebar ? 300 : 10)
                    .overlay(
                        MouseTrackingArea(mouseEntered: $showFloatingSidebar, xExit: 340)
                    )
                    .zIndex(2)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: showFloatingSidebar)
    }

    @ViewBuilder
    private var webView: some View {
        VStack(alignment: .leading, spacing: 0) {
            URLBar(
                onSidebarToggle: {
                    withAnimation(.spring(response: 0.2, dampingFraction: 1.0))
                    {
                        hide.toggle(.primary)  // Toggle sidebar with Cmd+S
                    }
                }
            )
            if let tab = tabManager.activeTab {
                if tab.isWebViewReady {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(isFullscreen && hide.side == .primary ? 0 : 8)
        .padding(
            isFullscreen && hide.side == .primary
                ? EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )
                : EdgeInsets(
                    top: 10,
                    leading: hide.side == .primary ? 10 : 0,
                    bottom: 10,
                    trailing: 10
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .ignoresSafeArea(.all)
    }
}
