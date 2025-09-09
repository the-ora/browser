import SwiftUI

struct FloatingSidebar: View {
    let isFullscreen: Bool
    @Environment(\.theme) var theme
    let sidebarCornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .leading) {
            SidebarView(isFullscreen: isFullscreen)
                .background(theme.subtleWindowBackgroundColor)
                .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .cornerRadius(sidebarCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: sidebarCornerRadius, style: .continuous)
                        .stroke(theme.invertedSolidWindowBackgroundColor.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(6)
    }
}
