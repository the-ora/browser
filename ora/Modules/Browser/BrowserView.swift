import AppKit
import SwiftUI

struct BrowserView: View {
    @Environment(\.theme) var theme
    @Environment(\.window) var window: NSWindow?
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloadManager: DownloadManager
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var privacyMode: PrivacyMode

    @State private var isFullscreen = false
    @State private var isMouseOverSidebar = false
    @State private var showFloatingSidebar = false
    @State private var sidebarPosition: SidebarPosition = .primary
    @StateObject private var primaryFraction = FractionHolder.usingUserDefaults(0.2, key: "ui.sidebar.fraction.primary")
    @StateObject private var secondaryFraction = FractionHolder.usingUserDefaults(
        0.2,
        key: "ui.sidebar.fraction.secondary"
    )
    @StateObject private var hiddenSidebar = SideHolder.usingUserDefaults(key: "ui.sidebar.visibility")

    private var currentFraction: FractionHolder { sidebarPosition == .primary ? primaryFraction : secondaryFraction }

    var body: some View {
        ZStack(alignment: .leading) {
            BrowserSplitView(
                sidebarPosition: sidebarPosition,
                hiddenSidebar: hiddenSidebar,
                sidebarFraction: currentFraction,
                isFullscreen: $isFullscreen,
                toggleSidebar: toggleSidebar
            )
            .ignoresSafeArea(.all)
            .background(theme.subtleWindowBackgroundColor)
            .background(
                BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea(.all)
            )
            .background(WindowAccessor(
                isSidebarHidden: hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary,
                isFloatingSidebar: $showFloatingSidebar,
                isFullscreen: $isFullscreen
            ))
            .overlay {
                if appState.showLauncher, tabManager.activeTab != nil {
                    LauncherView()
                }
                if appState.isFloatingTabSwitchVisible {
                    FloatingTabSwitcher()
                }
            }

            if hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary {
                FloatingSidebarOverlay(
                    showFloatingSidebar: $showFloatingSidebar,
                    isMouseOverSidebar: $isMouseOverSidebar,
                    sidebarFraction: currentFraction,
                    sidebarPosition: sidebarPosition,
                    isFullscreen: $isFullscreen,
                    isDownloadsPopoverOpen: downloadManager.isDownloadsPopoverOpen
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
            if hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary {
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
        let targetSide = sidebarPosition == .primary ? SplitSide.primary : .secondary
        withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
            hiddenSidebar.side =
                (hiddenSidebar.side == targetSide) ? nil : targetSide
        }
    }

    private func toggleSidebarPosition() {
        let targetSide = sidebarPosition == .primary ? SplitSide.primary : .secondary
        let wasHidden = hiddenSidebar.side == targetSide
        sidebarPosition =
            (sidebarPosition == .primary) ? .secondary : .primary
        if wasHidden {
            hiddenSidebar.side =
                sidebarPosition == .primary ? .primary : .secondary
        }
    }

    private func toggleMaximizeWindow() {
        window?.toggleMaximized()
    }
}
