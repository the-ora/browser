import SwiftUI

struct Brush1: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.30977 * width, y: 0.4446 * height))
        strokePath2.addLine(to: CGPoint(x: 0.07425 * width, y: 0.52602 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.16271 * width, y: 0.8089 * height),
            control1: CGPoint(x: -0.03701 * width, y: 0.5676 * height),
            control2: CGPoint(x: 0.11295 * width, y: 0.75939 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.45459 * width, y: 0.90442 * height),
            control1: CGPoint(x: 0.21248 * width, y: 0.85841 * height),
            control2: CGPoint(x: 0.4128 * width, y: 1.0151 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.53382 * width, y: 0.66751 * height))
        strokePath2.move(to: CGPoint(x: 0.09018 * width, y: 0.69268 * height))
        strokePath2.addLine(to: CGPoint(x: 0.21298 * width, y: 0.63005 * height))
        strokePath2.move(to: CGPoint(x: 0.29041 * width, y: 0.87485 * height))
        strokePath2.addLine(to: CGPoint(x: 0.34741 * width, y: 0.7638 * height))
        strokePath2.move(to: CGPoint(x: 0.71341 * width, y: 0.35237 * height))
        strokePath2.addLine(to: CGPoint(x: 0.9217 * width, y: 0.13683 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.83953 * width, y: 0.05468 * height),
            control1: CGPoint(x: 0.98339 * width, y: 0.07547 * height),
            control2: CGPoint(x: 0.89859 * width, y: -0.00409 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.62163 * width, y: 0.26106 * height))
        strokePath2.move(to: CGPoint(x: 0.51708 * width, y: 0.31815 * height))
        strokePath2.addLine(to: CGPoint(x: 0.56264 * width, y: 0.27283 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.62975 * width, y: 0.27617 * height),
            control1: CGPoint(x: 0.58056 * width, y: 0.255 * height),
            control2: CGPoint(x: 0.61183 * width, y: 0.25834 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.70085 * width, y: 0.3469 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.70085 * width, y: 0.41147 * height),
            control1: CGPoint(x: 0.71877 * width, y: 0.36473 * height),
            control2: CGPoint(x: 0.71877 * width, y: 0.39364 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.6553 * width, y: 0.45679 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.62973 * width, y: 0.50596 * height),
            control1: CGPoint(x: 0.64186 * width, y: 0.47015 * height),
            control2: CGPoint(x: 0.63293 * width, y: 0.48734 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.60725 * width, y: 0.63672 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.52957 * width, y: 0.66131 * height),
            control1: CGPoint(x: 0.60097 * width, y: 0.67324 * height),
            control2: CGPoint(x: 0.5559 * width, y: 0.6875 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.32329 * width, y: 0.4437 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.33844 * width, y: 0.36929 * height),
            control1: CGPoint(x: 0.29696 * width, y: 0.4175 * height),
            control2: CGPoint(x: 0.30174 * width, y: 0.37554 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.46987 * width, y: 0.34693 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.51708 * width, y: 0.31815 * height),
            control1: CGPoint(x: 0.4886 * width, y: 0.34374 * height),
            control2: CGPoint(x: 0.50365 * width, y: 0.33151 * height)
        )
        strokePath2.closeSubpath()
        path.addPath(strokePath2.strokedPath(StrokeStyle(
            lineWidth: 0.06818 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }
}
