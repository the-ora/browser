import SwiftUI

struct Brush2: Shape {
    // swiftlint:disable:next function_body_length
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.53409 * height))
        strokePath2.addLine(to: CGPoint(x: 0.6375 * width, y: 0.625 * height))
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.53409 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.0375 * width, y: 0.57276 * height),
            control1: CGPoint(x: 0.26353 * width, y: 0.6589 * height),
            control2: CGPoint(x: 0.13159 * width, y: 0.61504 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.1223 * width, y: 0.80682 * height),
            control1: CGPoint(x: 0.0375 * width, y: 0.66726 * height),
            control2: CGPoint(x: 0.07156 * width, y: 0.74633 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.4875 * width, y: 0.53409 * height))
        strokePath2.addLine(to: CGPoint(x: 0.6375 * width, y: 0.32563 * height))
        strokePath2.move(to: CGPoint(x: 0.6375 * width, y: 0.625 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.39528 * width, y: 0.94318 * height),
            control1: CGPoint(x: 0.62655 * width, y: 0.7176 * height),
            control2: CGPoint(x: 0.55883 * width, y: 0.90614 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.1223 * width, y: 0.80682 * height),
            control1: CGPoint(x: 0.30453 * width, y: 0.94318 * height),
            control2: CGPoint(x: 0.19588 * width, y: 0.89453 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.6375 * width, y: 0.625 * height))
        strokePath2.addLine(to: CGPoint(x: 0.76739 * width, y: 0.39773 * height))
        strokePath2.move(to: CGPoint(x: 0.1223 * width, y: 0.80682 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.39528 * width, y: 0.76136 * height),
            control1: CGPoint(x: 0.17422 * width, y: 0.8144 * height),
            control2: CGPoint(x: 0.3015 * width, y: 0.81591 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.6375 * width, y: 0.32563 * height))
        strokePath2.addLine(to: CGPoint(x: 0.82788 * width, y: 0.06106 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.90509 * width, y: 0.0397 * height),
            control1: CGPoint(x: 0.84323 * width, y: 0.03645 * height),
            control2: CGPoint(x: 0.87719 * width, y: 0.02706 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.9313 * width, y: 0.11092 * height),
            control1: CGPoint(x: 0.93404 * width, y: 0.05281 * height),
            control2: CGPoint(x: 0.94578 * width, y: 0.0847 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.76739 * width, y: 0.39773 * height))
        strokePath2.move(to: CGPoint(x: 0.6375 * width, y: 0.32563 * height))
        strokePath2.addLine(to: CGPoint(x: 0.76739 * width, y: 0.39773 * height))
        strokePath2.move(to: CGPoint(x: 0.1875 * width, y: 0.125 * height))
        strokePath2.addLine(to: CGPoint(x: 0.19855 * width, y: 0.15216 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.23458 * width, y: 0.21856 * height),
            control1: CGPoint(x: 0.21305 * width, y: 0.18777 * height),
            control2: CGPoint(x: 0.2203 * width, y: 0.20557 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.30763 * width, y: 0.25131 * height),
            control1: CGPoint(x: 0.24887 * width, y: 0.23155 * height),
            control2: CGPoint(x: 0.26846 * width, y: 0.23814 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.3375 * width, y: 0.26136 * height))
        strokePath2.addLine(to: CGPoint(x: 0.30763 * width, y: 0.27141 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.23458 * width, y: 0.30417 * height),
            control1: CGPoint(x: 0.26846 * width, y: 0.28459 * height),
            control2: CGPoint(x: 0.24887 * width, y: 0.29118 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.19855 * width, y: 0.37057 * height),
            control1: CGPoint(x: 0.2203 * width, y: 0.31716 * height),
            control2: CGPoint(x: 0.21305 * width, y: 0.33496 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.1875 * width, y: 0.39773 * height))
        strokePath2.addLine(to: CGPoint(x: 0.17645 * width, y: 0.37057 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.14042 * width, y: 0.30417 * height),
            control1: CGPoint(x: 0.16195 * width, y: 0.33496 * height),
            control2: CGPoint(x: 0.1547 * width, y: 0.31716 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.06737 * width, y: 0.27141 * height),
            control1: CGPoint(x: 0.12613 * width, y: 0.29118 * height),
            control2: CGPoint(x: 0.10654 * width, y: 0.28459 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.0375 * width, y: 0.26136 * height))
        strokePath2.addLine(to: CGPoint(x: 0.06737 * width, y: 0.25131 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.14042 * width, y: 0.21856 * height),
            control1: CGPoint(x: 0.10654 * width, y: 0.23814 * height),
            control2: CGPoint(x: 0.12613 * width, y: 0.23155 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.17645 * width, y: 0.15216 * height),
            control1: CGPoint(x: 0.1547 * width, y: 0.20557 * height),
            control2: CGPoint(x: 0.16195 * width, y: 0.18777 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.1875 * width, y: 0.125 * height))
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
