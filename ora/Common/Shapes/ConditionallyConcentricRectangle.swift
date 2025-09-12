import SwiftUI

/// Uses ConcentricRectangle on 26.0+, falls back to RoundedRectangle otherwise.
struct ConditionallyConcentricRectangle: Shape {
    var cornerRadius: CGFloat
    var style: RoundedCornerStyle = .continuous

    func path(in rect: CGRect) -> Path {
        if #available(macOS 26.0, *) {
            return ConcentricRectangle(
                corners: .concentric(
                    minimum: .fixed(
                        cornerRadius
                    )
                ),
                isUniform: true
            )
            .path(in: rect)
        } else {
            return RoundedRectangle(
                cornerRadius: cornerRadius,
                style: style
            )
            .path(in: rect)
        }
    }
}
