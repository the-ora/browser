import SwiftUI

struct BrowserContentContainer<Content: View>: View {
    @EnvironmentObject var tabManager: TabManager
    let content: () -> Content
    let isFullscreen: Bool
    let hideState: SideHolder

    let sidebarCornerRadius: CGFloat = {
        if #available(macOS 26, *) {
            return 8
        } else {
            return 6
        }
    }()

    init(isFullscreen: Bool, hideState: SideHolder, @ViewBuilder content: @escaping () -> Content) {
        self.isFullscreen = isFullscreen
        self.hideState = hideState
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(
                ConditionallyConcentricRectangle(
                    cornerRadius: isFullscreen && hideState.side == .primary ? 0 : sidebarCornerRadius
                )
            )
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
            .shadow(color: .black.opacity(0.15), radius: sidebarCornerRadius, x: 0, y: 2)
            .ignoresSafeArea(.all)
    }
}
