import SwiftUI

/// Uses ConcentricRectangle on 26.0+, falls back to RoundedRectangle otherwise.
struct ConditionallyConcentricRectangle: Shape {
    var cornerRadius: CGFloat
    var style: RoundedCornerStyle = .continuous

    // This is equivilent to building with Xcode 26.0+
    #if compiler(>=6.2)
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
    #else
        func path(in rect: CGRect) -> Path {
            return RoundedRectangle(
                cornerRadius: cornerRadius,
                style: style
            )
            .path(in: rect)
        }
    #endif
}
