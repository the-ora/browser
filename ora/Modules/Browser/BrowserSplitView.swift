import SwiftUI

enum SidebarPosition {
    case primary
    case secondary
}

struct BrowserSplitView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState

    @ObservedObject var hiddenSidebar: SideHolder
    @ObservedObject var sidebarFraction: FractionHolder

    let toggleSidebar: () -> Void

    private var targetSide: SplitSide {
        appState.sidebarPosition == .primary ? .primary : .secondary
    }

    private var splitFraction: FractionHolder {
        appState.sidebarPosition == .primary
            ? sidebarFraction
            : sidebarFraction.inverted()
    }

    private var minPF: CGFloat {
        appState.sidebarPosition == .primary ? 0.16 : 0.7
    }

    private var minSF: CGFloat {
        appState.sidebarPosition == .primary ? 0.7 : 0.16
    }

    private var prioritySide: SplitSide {
        appState.sidebarPosition == .primary ? .primary : .secondary
    }

    private var dragToHidePFlag: Bool {
        appState.sidebarPosition == .primary
    }

    private var dragToHideSFlag: Bool {
        appState.sidebarPosition == .secondary
    }

    var body: some View {
        HSplit(left: { primaryPane() }, right: { secondaryPane() })
            .hide(hiddenSidebar)
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
        if appState.sidebarPosition == .primary {
            if hiddenSidebar.side == .secondary {
                contentView()
            } else {
                SidebarView(toggleSidebar: toggleSidebar)
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func secondaryPane() -> some View {
        if appState.sidebarPosition == .secondary {
            if hiddenSidebar.side == .primary {
                contentView()
            } else {
                SidebarView(toggleSidebar: toggleSidebar)
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        if tabManager.activeTab != nil {
            BrowserContentContainer(hiddenSidebar: hiddenSidebar) {
                BrowserWebContentView(sidebarPosition: appState.sidebarPosition)
            }
        } else {
            BrowserContentContainer(hiddenSidebar: hiddenSidebar) {
                HomeView(sidebarToggle: toggleSidebar)
            }
        }
    }
}
