import SwiftUI

extension View {
    func gradientAnimatingBorder(color: Color, trigger: Bool) -> some View {
        modifier(
            GradientAnimatingBorder(
                color: color,
                trigger: trigger
            )
        )
    }

    func withTheme() -> some View {
        self.modifier(ThemeProvider())
    }

    @ViewBuilder
    func adaptiveGlassEffect(tintColor: Color? = nil, cornerRadius: CGFloat = 16) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tintColor), in: .rect(cornerRadius: cornerRadius))
                .glassEffectTransition(.materialize)
        } else {
            self.background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .clipShape(.rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func `if`(@ViewBuilder transform: (Self) -> some View) -> some View {
        transform(self)
    }
}
