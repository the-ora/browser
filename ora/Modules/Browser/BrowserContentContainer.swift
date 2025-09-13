import SwiftUI

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    let content: () -> Content
    let isFullscreen: Bool
    let hideState: SideHolder

    init(isFullscreen: Bool, hideState: SideHolder, @ViewBuilder content: @escaping () -> Content) {
        self.isFullscreen = isFullscreen
        self.hideState = hideState
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(isFullscreen && hideState.side == .primary ? 0 : 6)
            .padding(
                isFullscreen && hideState.side == .primary
                    ? EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                    : EdgeInsets(
                        top: 6,
                        leading: hideState.side == .primary ? 6 : 0,
                        bottom: 6,
                        trailing: 6
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            .ignoresSafeArea(.all)
    }
}
