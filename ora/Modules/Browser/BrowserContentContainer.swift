import SwiftUI

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    let content: () -> Content
    let isFullscreen: Bool
    let hiddenSidebar: SideHolder
    let sidebarPosition: SidebarPosition

    let cornerRadius: CGFloat = {
        if #available(macOS 26, *) {
            return 13
        } else {
            return 6
        }
    }()

    init(
        isFullscreen: Bool,
        hiddenSidebar: SideHolder,
        sidebarPosition: SidebarPosition,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isFullscreen = isFullscreen
        self.hiddenSidebar = hiddenSidebar
        self.sidebarPosition = sidebarPosition
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(
                ConditionallyConcentricRectangle(
                    cornerRadius: isFullscreen && (hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary) ?
                        0 : cornerRadius
                )
            )
            .padding(
                isFullscreen && (hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary)
                    ? EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                    : EdgeInsets(
                        top: 6,
                        leading: sidebarPosition != .primary || hiddenSidebar.side == .primary ? 6 : 0,
                        bottom: 6,
                        trailing: sidebarPosition != .secondary || hiddenSidebar.side == .secondary ? 6 : 0
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: cornerRadius, x: 0, y: 2)
            .ignoresSafeArea(.all)
    }
}
