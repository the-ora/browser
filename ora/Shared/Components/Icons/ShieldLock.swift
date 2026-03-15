import SwiftUI

struct ShieldLockIcon: Shape {
    // swiftlint:disable:next function_body_length
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.35227 * height))
        strokePath2.addLine(to: CGPoint(x: 0.4875 * width, y: 0.39773 * height))
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.42045 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.45214 * width, y: 0.40714 * height),
            control1: CGPoint(x: 0.47424 * width, y: 0.42045 * height),
            control2: CGPoint(x: 0.46152 * width, y: 0.41567 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.4375 * width, y: 0.375 * height),
            control1: CGPoint(x: 0.44277 * width, y: 0.39862 * height),
            control2: CGPoint(x: 0.4375 * width, y: 0.38706 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.45214 * width, y: 0.34286 * height),
            control1: CGPoint(x: 0.4375 * width, y: 0.36295 * height),
            control2: CGPoint(x: 0.44277 * width, y: 0.35138 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.4875 * width, y: 0.32955 * height),
            control1: CGPoint(x: 0.46152 * width, y: 0.33433 * height),
            control2: CGPoint(x: 0.47424 * width, y: 0.32955 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.52286 * width, y: 0.34286 * height),
            control1: CGPoint(x: 0.50076 * width, y: 0.32955 * height),
            control2: CGPoint(x: 0.51348 * width, y: 0.33433 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.5375 * width, y: 0.375 * height),
            control1: CGPoint(x: 0.53223 * width, y: 0.35138 * height),
            control2: CGPoint(x: 0.5375 * width, y: 0.36295 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.52286 * width, y: 0.40714 * height),
            control1: CGPoint(x: 0.5375 * width, y: 0.38706 * height),
            control2: CGPoint(x: 0.53223 * width, y: 0.39862 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.4875 * width, y: 0.42045 * height),
            control1: CGPoint(x: 0.51348 * width, y: 0.41567 * height),
            control2: CGPoint(x: 0.50076 * width, y: 0.42045 * height)
        )
        strokePath2.closeSubpath()
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.42045 * height))
        strokePath2.addLine(to: CGPoint(x: 0.45 * width, y: 0.57955 * height))
        strokePath2.addLine(to: CGPoint(x: 0.525 * width, y: 0.57955 * height))
        strokePath2.addLine(to: CGPoint(x: 0.4875 * width, y: 0.42045 * height))
        strokePath2.closeSubpath()
        strokePath2.move(to: CGPoint(x: 0.82294 * width, y: 0.10206 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.4875 * width, y: 0.03409 * height),
            control1: CGPoint(x: 0.72833 * width, y: 0.05926 * height),
            control2: CGPoint(x: 0.61255 * width, y: 0.03409 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.15206 * width, y: 0.10206 * height),
            control1: CGPoint(x: 0.36246 * width, y: 0.03409 * height),
            control2: CGPoint(x: 0.24668 * width, y: 0.05926 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.05998 * width, y: 0.16654 * height),
            control1: CGPoint(x: 0.10566 * width, y: 0.12305 * height),
            control2: CGPoint(x: 0.08246 * width, y: 0.13354 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.0375 * width, y: 0.29537 * height),
            control1: CGPoint(x: 0.0375 * width, y: 0.19953 * height),
            control2: CGPoint(x: 0.0375 * width, y: 0.23148 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.0375 * width, y: 0.45396 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.39615 * width, y: 0.91745 * height),
            control1: CGPoint(x: 0.0375 * width, y: 0.7123 * height),
            control2: CGPoint(x: 0.26462 * width, y: 0.85593 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.4875 * width, y: 0.94318 * height),
            control1: CGPoint(x: 0.43284 * width, y: 0.9346 * height),
            control2: CGPoint(x: 0.45117 * width, y: 0.94318 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.57885 * width, y: 0.91745 * height),
            control1: CGPoint(x: 0.52382 * width, y: 0.94318 * height),
            control2: CGPoint(x: 0.54217 * width, y: 0.9346 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.9375 * width, y: 0.45396 * height),
            control1: CGPoint(x: 0.71038 * width, y: 0.85593 * height),
            control2: CGPoint(x: 0.9375 * width, y: 0.7123 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.9375 * width, y: 0.29537 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.91502 * width, y: 0.16654 * height),
            control1: CGPoint(x: 0.9375 * width, y: 0.23148 * height),
            control2: CGPoint(x: 0.9375 * width, y: 0.19953 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.82294 * width, y: 0.10206 * height),
            control1: CGPoint(x: 0.89254 * width, y: 0.13354 * height),
            control2: CGPoint(x: 0.86934 * width, y: 0.12305 * height)
        )
        strokePath2.closeSubpath()
        path.addPath(strokePath2.strokedPath(StrokeStyle(
            lineWidth: 0.075 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }
}
