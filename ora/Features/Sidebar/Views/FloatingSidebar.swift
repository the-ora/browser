import SwiftUI

struct FloatingSidebar: View {
    @Environment(\.theme) var theme

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
            SidebarView()
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
