import SwiftUI

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sidebarManager: SidebarManager

    let content: () -> Content

    private var isCompleteFullscreen: Bool {
        appState.isFullscreen && sidebarManager.isSidebarHidden
    }

    private var cornerRadius: CGFloat {
        if #available(macOS 26, *) {
            return 13
        } else {
            return 6
        }
    }

    init(
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: isCompleteFullscreen ? 0 : cornerRadius, style: .continuous))
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
                        leading: sidebarManager.sidebarPosition != .primary || sidebarManager.hiddenSidebar
                            .side == .primary ? 6 : 0,
                        bottom: 6,
                        trailing: sidebarManager.sidebarPosition != .secondary || sidebarManager.hiddenSidebar
                            .side == .secondary ? 6 : 0
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: appState.isFullscreen)
            .shadow(color: .black.opacity(0.15), radius: isCompleteFullscreen ? 0 : cornerRadius, x: 0, y: 2)
            .ignoresSafeArea(.all)
    }
}
