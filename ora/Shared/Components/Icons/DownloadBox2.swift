import SwiftUI

struct DownloadBox2: Shape {
    // swiftlint:disable:next function_body_length
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.03571 * width, y: 0.60714 * height))
        strokePath2.addLine(to: CGPoint(x: 0.03571 * width, y: 0.41667 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.0915 * width, y: 0.0915 * height),
            control1: CGPoint(x: 0.03571 * width, y: 0.23708 * height),
            control2: CGPoint(x: 0.03571 * width, y: 0.14729 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.41667 * width, y: 0.03571 * height),
            control1: CGPoint(x: 0.14729 * width, y: 0.03571 * height),
            control2: CGPoint(x: 0.23708 * width, y: 0.03571 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.55952 * width, y: 0.03571 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.88469 * width, y: 0.0915 * height),
            control1: CGPoint(x: 0.7391 * width, y: 0.03571 * height),
            control2: CGPoint(x: 0.8289 * width, y: 0.03571 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.94048 * width, y: 0.41667 * height),
            control1: CGPoint(x: 0.94048 * width, y: 0.14729 * height),
            control2: CGPoint(x: 0.94048 * width, y: 0.23708 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.94048 * width, y: 0.60714 * height))
        strokePath2.move(to: CGPoint(x: 0.63095 * width, y: 0.60714 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.4881 * width, y: 0.75 * height),
            control1: CGPoint(x: 0.63095 * width, y: 0.60714 * height),
            control2: CGPoint(x: 0.52574 * width, y: 0.75 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.34524 * width, y: 0.60714 * height),
            control1: CGPoint(x: 0.45045 * width, y: 0.75 * height),
            control2: CGPoint(x: 0.34524 * width, y: 0.60714 * height)
        )
        strokePath2.move(to: CGPoint(x: 0.4881 * width, y: 0.72619 * height))
        strokePath2.addLine(to: CGPoint(x: 0.4881 * width, y: 0.41667 * height))
        strokePath2.move(to: CGPoint(x: 0.58333 * width, y: 0.94048 * height))
        strokePath2.addLine(to: CGPoint(x: 0.39286 * width, y: 0.94048 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.10535 * width, y: 0.89724 * height),
            control1: CGPoint(x: 0.23631 * width, y: 0.94048 * height),
            control2: CGPoint(x: 0.15804 * width, y: 0.94048 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.07895 * width, y: 0.87084 * height),
            control1: CGPoint(x: 0.09571 * width, y: 0.88932 * height),
            control2: CGPoint(x: 0.08687 * width, y: 0.88048 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.03571 * width, y: 0.58333 * height),
            control1: CGPoint(x: 0.03571 * width, y: 0.81815 * height),
            control2: CGPoint(x: 0.03571 * width, y: 0.73988 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.07895 * width, y: 0.29583 * height),
            control1: CGPoint(x: 0.03571 * width, y: 0.42679 * height),
            control2: CGPoint(x: 0.03571 * width, y: 0.34851 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.10535 * width, y: 0.26943 * height),
            control1: CGPoint(x: 0.08687 * width, y: 0.28619 * height),
            control2: CGPoint(x: 0.09571 * width, y: 0.27734 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.39286 * width, y: 0.22619 * height),
            control1: CGPoint(x: 0.15804 * width, y: 0.22619 * height),
            control2: CGPoint(x: 0.23631 * width, y: 0.22619 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.58333 * width, y: 0.22619 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.87084 * width, y: 0.26943 * height),
            control1: CGPoint(x: 0.73988 * width, y: 0.22619 * height),
            control2: CGPoint(x: 0.81815 * width, y: 0.22619 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.89724 * width, y: 0.29583 * height),
            control1: CGPoint(x: 0.88048 * width, y: 0.27734 * height),
            control2: CGPoint(x: 0.88932 * width, y: 0.28619 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.94048 * width, y: 0.58333 * height),
            control1: CGPoint(x: 0.94048 * width, y: 0.34851 * height),
            control2: CGPoint(x: 0.94048 * width, y: 0.42679 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.89724 * width, y: 0.87084 * height),
            control1: CGPoint(x: 0.94048 * width, y: 0.73988 * height),
            control2: CGPoint(x: 0.94048 * width, y: 0.81815 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.87084 * width, y: 0.89724 * height),
            control1: CGPoint(x: 0.88932 * width, y: 0.88048 * height),
            control2: CGPoint(x: 0.88048 * width, y: 0.88932 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.58333 * width, y: 0.94048 * height),
            control1: CGPoint(x: 0.81815 * width, y: 0.94048 * height),
            control2: CGPoint(x: 0.73988 * width, y: 0.94048 * height)
        )
        strokePath2.closeSubpath()
        path.addPath(strokePath2.strokedPath(StrokeStyle(
            lineWidth: 0.07143 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }
}
