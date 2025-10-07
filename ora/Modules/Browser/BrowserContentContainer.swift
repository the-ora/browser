import SwiftUI

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState

    let content: () -> Content
    let hiddenSidebar: SideHolder
    let sidebarPosition: SidebarPosition

    private var isSidebarHidden: Bool {
        hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary
    }

    private var isCompleteFullscreen: Bool {
        appState.isFullscreen && isSidebarHidden
    }

    private var cornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 13
        } else {
            return 6
        }
    }

    init(
        hiddenSidebar: SideHolder,
        sidebarPosition: SidebarPosition,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hiddenSidebar = hiddenSidebar
        self.sidebarPosition = sidebarPosition
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(ConditionallyConcentricRectangle(cornerRadius: isCompleteFullscreen ? 0 : cornerRadius))
            .padding(
                isCompleteFullscreen
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
            .animation(.easeInOut(duration: 0.3), value: appState.isFullscreen)
            // .shadow(color: .black.opacity(0.15), radius: cornerRadius, x: 0, y: 2)
            .ignoresSafeArea(.all)
    }
}
