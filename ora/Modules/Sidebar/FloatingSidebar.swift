import SwiftUI

struct FloatingSidebar: View {
    let isFullscreen: Bool
    @Environment(\.theme) var theme

    var body: some View {
        let clipShape = ConditionallyConcentricRectangle(cornerRadius: 8)

        ZStack(alignment: .leading) {
            SidebarView(isFullscreen: isFullscreen)
                .background(theme.subtleWindowBackgroundColor)
                .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .clipShape(clipShape)
                .overlay(
                    clipShape
                        .stroke(theme.invertedSolidWindowBackgroundColor.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(6)
    }
}
