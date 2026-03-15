import SwiftUI

struct ShieldBanIcon: Shape {
    // swiftlint:disable:next function_body_length
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.8459 * width, y: 0.66408 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.89773 * width, y: 0.45396 * height),
            control1: CGPoint(x: 0.87744 * width, y: 0.60464 * height),
            control2: CGPoint(x: 0.89773 * width, y: 0.53493 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.89773 * width, y: 0.29537 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.87729 * width, y: 0.16654 * height),
            control1: CGPoint(x: 0.89773 * width, y: 0.23148 * height),
            control2: CGPoint(x: 0.89773 * width, y: 0.19953 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.79358 * width, y: 0.10206 * height),
            control1: CGPoint(x: 0.85685 * width, y: 0.13354 * height),
            control2: CGPoint(x: 0.83576 * width, y: 0.12305 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.48864 * width, y: 0.03409 * height),
            control1: CGPoint(x: 0.70757 * width, y: 0.05926 * height),
            control2: CGPoint(x: 0.60231 * width, y: 0.03409 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.25428 * width, y: 0.07246 * height),
            control1: CGPoint(x: 0.40443 * width, y: 0.03409 * height),
            control2: CGPoint(x: 0.32485 * width, y: 0.0479 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.13144 * width, y: 0.13144 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.09998 * width, y: 0.16654 * height),
            control1: CGPoint(x: 0.11938 * width, y: 0.14044 * height),
            control2: CGPoint(x: 0.10961 * width, y: 0.15099 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.07955 * width, y: 0.29537 * height),
            control1: CGPoint(x: 0.07955 * width, y: 0.19953 * height),
            control2: CGPoint(x: 0.07955 * width, y: 0.23148 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.07955 * width, y: 0.45396 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.40559 * width, y: 0.91745 * height),
            control1: CGPoint(x: 0.07955 * width, y: 0.71229 * height),
            control2: CGPoint(x: 0.28602 * width, y: 0.85592 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.48864 * width, y: 0.94318 * height),
            control1: CGPoint(x: 0.43894 * width, y: 0.9346 * height),
            control2: CGPoint(x: 0.45561 * width, y: 0.94318 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.57168 * width, y: 0.91745 * height),
            control1: CGPoint(x: 0.52166 * width, y: 0.94318 * height),
            control2: CGPoint(x: 0.53833 * width, y: 0.9346 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.77005 * width, y: 0.77005 * height),
            control1: CGPoint(x: 0.62865 * width, y: 0.88813 * height),
            control2: CGPoint(x: 0.70536 * width, y: 0.84018 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.03409 * width, y: 0.03409 * height))
        strokePath2.addLine(to: CGPoint(x: 0.94318 * width, y: 0.94318 * height))
        path.addPath(strokePath2.strokedPath(StrokeStyle(
            lineWidth: 0.06818 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }
}
