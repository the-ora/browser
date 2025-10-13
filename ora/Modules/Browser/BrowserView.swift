import AppKit
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

    @State private var isMouseOverURLBar = false
    @State private var showFloatingURLBar = false
    @State private var isMouseOverSidebar = false
    @State private var showFloatingSidebar = false

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
                    isDownloadsPopoverOpen: downloadManager.isDownloadsPopoverOpen
                )
            }

            if toolbarManager.isToolbarHidden {
                FloatingURLBar(
                    showFloatingURLBar: $showFloatingURLBar,
                    isMouseOverURLBar: $isMouseOverURLBar
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarManager.toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarPosition)) { _ in
            sidebarManager.toggleSidebarPosition()
        }
        .onChange(of: downloadManager.isDownloadsPopoverOpen) { _, isOpen in
            if sidebarManager.isSidebarHidden {
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
