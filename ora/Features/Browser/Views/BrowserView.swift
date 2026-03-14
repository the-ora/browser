import AppKit
import Inject
import SwiftUI

struct BrowserView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var privacyMode: PrivacyMode
    @EnvironmentObject private var sidebarManager: SidebarManager
    @EnvironmentObject private var toolbarManager: ToolbarManager

    @ObserveInjection var inject

    @State private var isMouseOverURLBar = false
    @State private var showFloatingURLBar = false
    @State private var isMouseOverSidebar = false
    @State private var showFloatingSidebar = false

    // MARK: - Sidebar mouse shield

    private static let removeShieldJS = "document.getElementById('ora-sb-shield')?.remove();"

    private var clampedSidebarFraction: CGFloat {
        min(
            max(
                sidebarManager.currentFraction.value,
                FloatingSidebarOverlay.minFraction
            ),
            FloatingSidebarOverlay.maxFraction
        )
    }

    /// Injects/removes a transparent shield div in the web page to block
    /// hover effects and cursor changes behind the floating sidebar.
    private func injectSidebarMouseShield(visible: Bool) {
        guard let activeTab = tabManager.activeTab else { return }
        if visible {
            let side = sidebarManager.sidebarPosition == .primary ? "left" : "right"
            let widthVW = clampedSidebarFraction * 100
            activeTab.evaluateJavaScript(
                """
                var e = document.getElementById('ora-sb-shield');
                if (e) e.remove();
                var d = document.createElement('div');
                d.id = 'ora-sb-shield';
                d.style.position = 'fixed';
                d.style.top = '0';
                d.style.\(side) = '0';
                d.style.width = '\(widthVW)vw';
                d.style.height = '100vh';
                d.style.zIndex = '2147483647';
                d.style.pointerEvents = 'auto';
                d.style.cursor = 'default';
                document.documentElement.appendChild(d);
                """
            )
        } else {
            activeTab.evaluateJavaScript(Self.removeShieldJS)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            BrowserSplitView()
                .ignoresSafeArea(.all)
                .background(theme.subtleWindowBackgroundColor)
                .background(
                    BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                        .ignoresSafeArea(.all)
                )
                .overlay {
                    if appState.showLauncher, tabManager.activeTab != nil {
                        LauncherView()
                    }
                    if appState.isFloatingTabSwitchVisible {
                        FloatingTabSwitcher()
                    }
                }

            if sidebarManager.isSidebarHidden {
                FloatingSidebarOverlay(
                    showFloatingSidebar: $showFloatingSidebar,
                    isMouseOverSidebar: $isMouseOverSidebar,
                    sidebarFraction: sidebarManager.currentFraction,
                    isDownloadsOpen: downloadManager.isShowingDownloadsHistory
                )
            }

            if toolbarManager.isToolbarHidden, sidebarManager.sidebarPosition != .primary {
                FloatingURLBar(
                    showFloatingURLBar: $showFloatingURLBar,
                    isMouseOverURLBar: $isMouseOverURLBar
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
        .enableInjection()
        .animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
        .onChange(of: showFloatingSidebar) { _, visible in
            injectSidebarMouseShield(visible: visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarManager.toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarPosition)) { _ in
            sidebarManager.toggleSidebarPosition()
        }
        .onChange(of: downloadManager.isShowingDownloadsHistory) { _, isOpen in
            if sidebarManager.isSidebarHidden {
                if isOpen {
                    showFloatingSidebar = true
                } else if !isMouseOverSidebar {
                    showFloatingSidebar = false
                }
            }
        }
        .onChange(of: tabManager.activeTab) { oldTab, newTab in
            if showFloatingSidebar {
                oldTab?.evaluateJavaScript(Self.removeShieldJS)
                injectSidebarMouseShield(visible: true)
            }
            if let tab = newTab, !tab.isWebViewReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    tab.restoreTransientState(
                        historyManager: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            }
        }
        .onAppear {
            if let tab = tabManager.activeTab, !tab.isWebViewReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tab.restoreTransientState(
                        historyManager: historyManager,
                        downloadManager: downloadManager,
                        tabManager: tabManager,
                        isPrivate: privacyMode.isPrivate
                    )
                }
            }
        }
    }
}
