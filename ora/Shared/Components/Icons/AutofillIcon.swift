import SwiftUI

struct AutofillIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.49855 * width, y: 0.38393 * height))
        path.addLine(to: CGPoint(x: 0.49855 * width, y: 0.6125 * height))
        path.move(to: CGPoint(x: 0.41799 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.5791 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.5791 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.41794 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.25352 * width, y: 0.38393 * height))
        path.addLine(to: CGPoint(x: 0.25352 * width, y: 0.6125 * height))
        path.move(to: CGPoint(x: 0.17297 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.33408 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.33408 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.17297 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.74357 * width, y: 0.38393 * height))
        path.addLine(to: CGPoint(x: 0.74357 * width, y: 0.6125 * height))
        path.move(to: CGPoint(x: 0.66301 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.82413 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.82413 * width, y: 0.44107 * height))
        path.addLine(to: CGPoint(x: 0.66297 * width, y: 0.55536 * height))
        path.move(to: CGPoint(x: 0.96366 * width, y: 0.49821 * height))
        path.addCurve(
            to: CGPoint(x: 0.90915 * width, y: 0.88839 * height),
            control1: CGPoint(x: 0.96366 * width, y: 0.7137 * height),
            control2: CGPoint(x: 0.96366 * width, y: 0.82147 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.59157 * width, y: 0.95536 * height),
            control1: CGPoint(x: 0.85464 * width, y: 0.9553 * height),
            control2: CGPoint(x: 0.76697 * width, y: 0.95536 * height)
        )
        path.addLine(to: CGPoint(x: 0.40552 * width, y: 0.95536 * height))
        path.addCurve(
            to: CGPoint(x: 0.08794 * width, y: 0.88839 * height),
            control1: CGPoint(x: 0.23013 * width, y: 0.95536 * height),
            control2: CGPoint(x: 0.14241 * width, y: 0.95536 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.03343 * width, y: 0.49821 * height),
            control1: CGPoint(x: 0.03348 * width, y: 0.82141 * height),
            control2: CGPoint(x: 0.03343 * width, y: 0.7137 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.08794 * width, y: 0.10804 * height),
            control1: CGPoint(x: 0.03343 * width, y: 0.28273 * height),
            control2: CGPoint(x: 0.03343 * width, y: 0.17496 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.40552 * width, y: 0.04107 * height),
            control1: CGPoint(x: 0.14245 * width, y: 0.04113 * height),
            control2: CGPoint(x: 0.23013 * width, y: 0.04107 * height)
        )
        path.addLine(to: CGPoint(x: 0.59157 * width, y: 0.04107 * height))
        path.addCurve(
            to: CGPoint(x: 0.90915 * width, y: 0.10804 * height),
            control1: CGPoint(x: 0.76697 * width, y: 0.04107 * height),
            control2: CGPoint(x: 0.85469 * width, y: 0.04107 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.95892 * width, y: 0.26964 * height),
            control1: CGPoint(x: 0.93957 * width, y: 0.14536 * height),
            control2: CGPoint(x: 0.95301 * width, y: 0.19536 * height)
        )
        return path
    }
}
