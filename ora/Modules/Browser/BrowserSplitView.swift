import SwiftUI

enum SidebarPosition {
    case primary
    case secondary
}

struct BrowserSplitView: View {
    @EnvironmentObject var tabManager: TabManager

    let sidebarPosition: SidebarPosition
    @ObservedObject var hiddenSidebar: SideHolder
    @ObservedObject var sidebarFraction: FractionHolder
    @Binding var isFullscreen: Bool
    let toggleSidebar: () -> Void

    private var targetSide: SplitSide {
        sidebarPosition == .primary ? .primary : .secondary
    }

    private var splitFraction: FractionHolder {
        sidebarPosition == .primary
            ? sidebarFraction
            : sidebarFraction.inverted()
    }

    private var minPF: CGFloat {
        sidebarPosition == .primary ? 0.16 : 0.7
    }

    private var minSF: CGFloat {
        sidebarPosition == .primary ? 0.7 : 0.16
    }

    private var prioritySide: SplitSide {
        sidebarPosition == .primary ? .primary : .secondary
    }

    private var dragToHidePFlag: Bool {
        sidebarPosition == .primary
    }

    private var dragToHideSFlag: Bool {
        sidebarPosition == .secondary
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
        if sidebarPosition == .primary {
            if hiddenSidebar.side == .secondary {
                contentView()
            } else {
                SidebarView(
                    isFullscreen: $isFullscreen, sidebarPosition: .primary
                )
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func secondaryPane() -> some View {
        if sidebarPosition == .secondary {
            if hiddenSidebar.side == .primary {
                contentView()
            } else {
                SidebarView(
                    isFullscreen: $isFullscreen, sidebarPosition: .secondary
                )
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        if tabManager.activeTab != nil {
            BrowserContentContainer(
                isFullscreen: isFullscreen,
                hiddenSidebar: hiddenSidebar,
                sidebarPosition: sidebarPosition
            ) {
                BrowserWebContentView(sidebarPosition: sidebarPosition)
            }
        } else {
            BrowserContentContainer(
                isFullscreen: isFullscreen,
                hiddenSidebar: hiddenSidebar,
                sidebarPosition: sidebarPosition
            ) {
                HomeView(sidebarToggle: toggleSidebar)
            }
        }
    }
}
