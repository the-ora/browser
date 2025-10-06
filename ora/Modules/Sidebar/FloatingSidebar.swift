import SwiftUI

struct FloatingSidebar: View {
    @Environment(\.theme) var theme

    @Binding var isFullscreen: Bool
    let sidebarPosition: SidebarPosition
    let sidebarCornerRadius: CGFloat = {
        if #available(macOS 26, *) {
            return 13
        } else {
            return 6
        }
    }()

    var body: some View {
        let clipShape = ConditionallyConcentricRectangle(cornerRadius: sidebarCornerRadius)

        ZStack(alignment: .leading) {
            SidebarView(isFullscreen: isFullscreen, sidebarPosition: sidebarPosition)
                .background(theme.subtleWindowBackgroundColor)
                .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .clipShape(clipShape)
                .overlay(clipShape
                    .stroke(theme.invertedSolidWindowBackgroundColor.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(6)
    }
}
