import SwiftUI

struct BrowserSplitView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var toolbarManager: ToolbarManager
    @EnvironmentObject var sidebarManager: SidebarManager

    private var targetSide: SplitSide {
        sidebarManager.sidebarPosition == .primary ? .primary : .secondary
    }

    private var splitFraction: FractionHolder {
        sidebarManager.sidebarPosition == .primary
            ? sidebarManager.currentFraction
            : sidebarManager.currentFraction.inverted()
    }

    private var minPF: CGFloat {
        sidebarManager.sidebarPosition == .primary ? 0.16 : 0.7
    }

    private var minSF: CGFloat {
        sidebarManager.sidebarPosition == .primary ? 0.7 : 0.16
    }

    private var prioritySide: SplitSide {
        sidebarManager.sidebarPosition == .primary ? .primary : .secondary
    }

    private var dragToHidePFlag: Bool {
        sidebarManager.sidebarPosition == .primary
    }

    private var dragToHideSFlag: Bool {
        sidebarManager.sidebarPosition == .secondary
    }

    var body: some View {
        HSplit(left: { primaryPane() }, right: { secondaryPane() })
            .hide(sidebarManager.hiddenSidebar)
            .splitter { Splitter.invisible() }
            .fraction(splitFraction)
            .constraints(
                minPFraction: minPF,
                minSFraction: minSF,
                priority: prioritySide,
                dragToHideP: dragToHidePFlag,
                dragToHideS: dragToHideSFlag
            )
            .styling(hideSplitter: true)
    }

    @ViewBuilder
    private func primaryPane() -> some View {
        paneContent(
            isSidebarPane: sidebarManager.sidebarPosition == .primary,
            isOtherPaneHidden: sidebarManager.hiddenSidebar.side == .secondary
        )
    }

    @ViewBuilder
    private func secondaryPane() -> some View {
        paneContent(
            isSidebarPane: sidebarManager.sidebarPosition == .secondary,
            isOtherPaneHidden: sidebarManager.hiddenSidebar.side == .primary
        )
    }

    @ViewBuilder
    private func paneContent(isSidebarPane: Bool, isOtherPaneHidden: Bool) -> some View {
        if isSidebarPane, !isOtherPaneHidden {
            SidebarView()
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        if tabManager.activeTab == nil {
            BrowserContentContainer {
                HomeView()
            }
        }
        let activeId = tabManager.activeTab?.id
        ZStack {
            ForEach(tabManager.tabsToRender.filter { !($0.id == activeId || tabManager.isInSplit(tab: $0)) }) { tab in
                if tab.isWebViewReady {
                    BrowserContentContainer {
                        BrowserWebContentView(tab: tab)
                    }
                    .opacity(0)
                    .allowsHitTesting(
                        false
                    )
                }
            }
        }
        HStack {
            let tabs = tabManager.tabsToRender.filter { $0.id == activeId || tabManager.isInSplit(tab: $0) }
            if tabs.allSatisfy(\.isWebViewReady) {
                ForEach(tabs) { tab in
                    BrowserContentContainer {
                        BrowserWebContentView(tab: tab)
                    }
                }
            }
        }
    }
}
