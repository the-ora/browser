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
    func adaptiveGlassEffect(
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat = 16,
        strokeColor: Color? = nil,
        strokeOpacity: Double = 0.3,
        strokeWidth: CGFloat = 1.0,
        strokeInset: CGFloat = 0.0,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 0,
        shadowOffset: (x: CGFloat, y: CGFloat) = (0, 0)
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(backgroundColor), in: .rect(cornerRadius: cornerRadius))
                .glassEffectTransition(.materialize)
        } else {
            self
                .background(backgroundColor ?? Color.clear)
                .background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
                .clipShape(.rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .inset(by: strokeInset)
                        .stroke(
                            strokeColor?.opacity(strokeOpacity) ?? Color.clear,
                            lineWidth: strokeWidth
                        )
                )
                .shadow(
                    color: shadowColor ?? Color.clear,
                    radius: shadowRadius,
                    x: shadowOffset.x,
                    y: shadowOffset.y
                )
        }
    }

    @ViewBuilder
    func `if`(@ViewBuilder transform: (Self) -> some View) -> some View {
        transform(self)
    }
}
