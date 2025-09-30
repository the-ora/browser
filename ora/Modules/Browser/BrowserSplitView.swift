import SwiftUI

enum SidebarPosition {
    case primary
    case secondary
}

struct BrowserSplitView: View {
    @EnvironmentObject var tabManager: TabManager

    let sidebarPosition: SidebarPosition
    @ObservedObject var sidebarVisibility: SideHolder
    @ObservedObject var sidebarFraction: FractionHolder
    let isFullscreen: Bool
    let toggleSidebar: () -> Void

    private var targetSide: SplitSide {
        sidebarPosition == .primary ? .primary : .secondary
    }

    private var fractionValue: CGFloat {
        sidebarPosition == .primary ? sidebarFraction.value : 0.8
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
            .hide(sidebarVisibility)
            .splitter { Splitter.invisible() }
            .fraction(sidebarFraction)
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
            if sidebarVisibility.side == .secondary {
                contentView()
            } else {
                SidebarView(
                    isFullscreen: isFullscreen, sidebarPosition: .primary
                )
            }
        } else {
            contentView()
        }
    }

    @ViewBuilder
    private func secondaryPane() -> some View {
        if sidebarPosition == .secondary {
            if sidebarVisibility.side == .primary {
                contentView()
            } else {
                SidebarView(
                    isFullscreen: isFullscreen, sidebarPosition: .secondary
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
                hideState: sidebarVisibility,
                sidebarPosition: sidebarPosition
            ) {
                BrowserWebContentView(sidebarPosition: sidebarPosition)
            }
        } else {
            BrowserContentContainer(
                isFullscreen: isFullscreen,
                hideState: sidebarVisibility,
                sidebarPosition: sidebarPosition
            ) {
                HomeView(sidebarToggle: toggleSidebar)
            }
        }
    }
}
