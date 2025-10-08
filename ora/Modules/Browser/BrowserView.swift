import AppKit
import SwiftUI

struct BrowserView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var privacyMode: PrivacyMode

    @State private var isMouseOverURLBar = false
    @State private var showFloatingURLBar = false
    @State private var isMouseOverSidebar = false
    @State private var showFloatingSidebar = false

    @StateObject private var primaryFraction = FractionHolder.usingUserDefaults(0.2, key: "ui.sidebar.fraction.primary")
    @StateObject private var secondaryFraction = FractionHolder.usingUserDefaults(
        0.2,
        key: "ui.sidebar.fraction.secondary"
    )
    @StateObject private var hiddenSidebar = SideHolder.usingUserDefaults(key: "ui.sidebar.visibility")

    private var currentFraction: FractionHolder {
        appState.sidebarPosition == .primary ? primaryFraction : secondaryFraction
    }

    private var isSidebarHidden: Bool {
        hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary
    }

    var body: some View {
        ZStack(alignment: .top) {
            BrowserSplitView(
                hiddenSidebar: hiddenSidebar,
                sidebarFraction: currentFraction,
                toggleSidebar: toggleSidebar
            )
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

            if isSidebarHidden {
                FloatingSidebarOverlay(
                    showFloatingSidebar: $showFloatingSidebar,
                    isMouseOverSidebar: $isMouseOverSidebar,
                    sidebarFraction: currentFraction,
                    isDownloadsPopoverOpen: downloadManager.isDownloadsPopoverOpen
                )
            }

            if appState.isToolbarHidden, isSidebarHidden {
                FloatingURLBar(
                    showFloatingURLBar: $showFloatingURLBar,
                    isMouseOverURLBar: $isMouseOverURLBar
                )
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
            if isSidebarHidden {
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
        .onAppear {
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

    // MARK: - Actions

    private func toggleSidebar() {
        let targetSide = appState.sidebarPosition == .primary ? SplitSide.primary : .secondary
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            hiddenSidebar.side =
                (hiddenSidebar.side == targetSide) ? nil : targetSide
        }
    }

    private func toggleSidebarPosition() {
        let targetSide = appState.sidebarPosition == .primary ? SplitSide.primary : .secondary
        let wasHidden = hiddenSidebar.side == targetSide
        appState.sidebarPosition =
            (appState.sidebarPosition == .primary) ? .secondary : .primary
        if wasHidden {
            hiddenSidebar.side =
                appState.sidebarPosition == .primary ? .primary : .secondary
        }
    }
}
