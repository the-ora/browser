import SwiftUI

struct FloatingSidebar: View {
    let isFullscreen: Bool
    @Environment(\.theme) var theme

    var body: some View {
        ZStack(alignment: .leading) {
            SidebarView(isFullscreen: isFullscreen)
                .adaptiveGlassEffect(
                    backgroundColor: theme.subtleWindowBackgroundColor,
                    cornerRadius: 8,
                    strokeColor: theme.invertedSolidWindowBackgroundColor
                )
        }
        .padding(6)
    }
}
