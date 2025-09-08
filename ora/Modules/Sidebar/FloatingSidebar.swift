import SwiftUI

struct FloatingSidebar: View {
    let isFullscreen: Bool
    @Environment(\.theme) var theme

    var body: some View {
        ZStack(alignment: .leading) {
            SidebarView(isFullscreen: isFullscreen)
                .background(theme.subtleWindowBackgroundColor)
                .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.invertedSolidWindowBackgroundColor.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(6)
    }
}
