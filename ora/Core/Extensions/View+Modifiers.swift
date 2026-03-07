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
}
