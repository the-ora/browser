import SwiftUI

struct CopyIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let outlinePath = makeOutlinePath(in: rect)

        path.addPath(outlinePath.strokedPath(StrokeStyle(
            lineWidth: 0.06818 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }

    private func makeOutlinePath(in rect: CGRect) -> Path {
        let width = rect.size.width
        let height = rect.size.height
        var outlinePath = Path()

        outlinePath.move(to: CGPoint(x: 0.7159 * width, y: 0.35227 * height))
        outlinePath.addCurve(
            to: CGPoint(x: 0.67464 * width, y: 0.10057 * height),
            control1: CGPoint(x: 0.7158 * width, y: 0.21786 * height),
            control2: CGPoint(x: 0.71376 * width, y: 0.14824 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.64944 * width, y: 0.07536 * height),
            control1: CGPoint(x: 0.66708 * width, y: 0.09136 * height),
            control2: CGPoint(x: 0.65864 * width, y: 0.08292 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.375 * width, y: 0.03409 * height),
            control1: CGPoint(x: 0.59915 * width, y: 0.03409 * height),
            control2: CGPoint(x: 0.52443 * width, y: 0.03409 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.10057 * width, y: 0.07536 * height),
            control1: CGPoint(x: 0.22557 * width, y: 0.03409 * height),
            control2: CGPoint(x: 0.15085 * width, y: 0.03409 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.07536 * width, y: 0.10057 * height),
            control1: CGPoint(x: 0.09136 * width, y: 0.08292 * height),
            control2: CGPoint(x: 0.08292 * width, y: 0.09136 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.03409 * width, y: 0.375 * height),
            control1: CGPoint(x: 0.03409 * width, y: 0.15085 * height),
            control2: CGPoint(x: 0.03409 * width, y: 0.22557 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.07536 * width, y: 0.64944 * height),
            control1: CGPoint(x: 0.03409 * width, y: 0.52443 * height),
            control2: CGPoint(x: 0.03409 * width, y: 0.59915 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.10057 * width, y: 0.67464 * height),
            control1: CGPoint(x: 0.08292 * width, y: 0.65864 * height),
            control2: CGPoint(x: 0.09136 * width, y: 0.66708 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.35227 * width, y: 0.7159 * height),
            control1: CGPoint(x: 0.14824 * width, y: 0.71376 * height),
            control2: CGPoint(x: 0.21786 * width, y: 0.7158 * height)
        )
        outlinePath.move(to: CGPoint(x: 0.35227 * width, y: 0.625 * height))
        outlinePath.addCurve(
            to: CGPoint(x: 0.39221 * width, y: 0.39221 * height),
            control1: CGPoint(x: 0.35227 * width, y: 0.49644 * height),
            control2: CGPoint(x: 0.35227 * width, y: 0.43215 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.625 * width, y: 0.35227 * height),
            control1: CGPoint(x: 0.43215 * width, y: 0.35227 * height),
            control2: CGPoint(x: 0.49644 * width, y: 0.35227 * height)
        )
        outlinePath.addLine(to: CGPoint(x: 0.67045 * width, y: 0.35227 * height))
        outlinePath.addCurve(
            to: CGPoint(x: 0.90324 * width, y: 0.39221 * height),
            control1: CGPoint(x: 0.79902 * width, y: 0.35227 * height),
            control2: CGPoint(x: 0.8633 * width, y: 0.35227 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.94318 * width, y: 0.625 * height),
            control1: CGPoint(x: 0.94318 * width, y: 0.43215 * height),
            control2: CGPoint(x: 0.94318 * width, y: 0.49644 * height)
        )
        outlinePath.addLine(to: CGPoint(x: 0.94318 * width, y: 0.67045 * height))
        outlinePath.addCurve(
            to: CGPoint(x: 0.90324 * width, y: 0.90324 * height),
            control1: CGPoint(x: 0.94318 * width, y: 0.79902 * height),
            control2: CGPoint(x: 0.94318 * width, y: 0.8633 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.67045 * width, y: 0.94318 * height),
            control1: CGPoint(x: 0.8633 * width, y: 0.94318 * height),
            control2: CGPoint(x: 0.79902 * width, y: 0.94318 * height)
        )
        outlinePath.addLine(to: CGPoint(x: 0.625 * width, y: 0.94318 * height))
        outlinePath.addCurve(
            to: CGPoint(x: 0.39221 * width, y: 0.90324 * height),
            control1: CGPoint(x: 0.49644 * width, y: 0.94318 * height),
            control2: CGPoint(x: 0.43215 * width, y: 0.94318 * height)
        )
        outlinePath.addCurve(
            to: CGPoint(x: 0.35227 * width, y: 0.67045 * height),
            control1: CGPoint(x: 0.35227 * width, y: 0.8633 * height),
            control2: CGPoint(x: 0.35227 * width, y: 0.79902 * height)
        )
        outlinePath.addLine(to: CGPoint(x: 0.35227 * width, y: 0.625 * height))
        outlinePath.closeSubpath()

        return outlinePath
    }
}
