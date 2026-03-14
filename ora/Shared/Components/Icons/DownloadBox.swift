import SwiftUI

struct DownloadBox: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        var strokePath2 = Path()
        strokePath2.move(to: CGPoint(x: 0.03571 * width, y: 0.22619 * height))
        strokePath2.addLine(to: CGPoint(x: 0.03571 * width, y: 0.55952 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.0915 * width, y: 0.88469 * height),
            control1: CGPoint(x: 0.03571 * width, y: 0.7391 * height),
            control2: CGPoint(x: 0.03571 * width, y: 0.8289 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.41667 * width, y: 0.94048 * height),
            control1: CGPoint(x: 0.14729 * width, y: 0.94048 * height),
            control2: CGPoint(x: 0.23708 * width, y: 0.94048 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.55952 * width, y: 0.94048 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.88469 * width, y: 0.88469 * height),
            control1: CGPoint(x: 0.73911 * width, y: 0.94048 * height),
            control2: CGPoint(x: 0.8289 * width, y: 0.94048 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.94048 * width, y: 0.55952 * height),
            control1: CGPoint(x: 0.94048 * width, y: 0.8289 * height),
            control2: CGPoint(x: 0.94048 * width, y: 0.7391 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.94048 * width, y: 0.22619 * height))
        strokePath2.move(to: CGPoint(x: 0.03571 * width, y: 0.22619 * height))
        strokePath2.addLine(to: CGPoint(x: 0.94048 * width, y: 0.22619 * height))
        strokePath2.move(to: CGPoint(x: 0.03571 * width, y: 0.22619 * height))
        strokePath2.addLine(to: CGPoint(x: 0.06429 * width, y: 0.1881 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.18863 * width, y: 0.05582 * height),
            control1: CGPoint(x: 0.12037 * width, y: 0.11332 * height),
            control2: CGPoint(x: 0.14841 * width, y: 0.07593 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.36905 * width, y: 0.03571 * height),
            control1: CGPoint(x: 0.22884 * width, y: 0.03571 * height),
            control2: CGPoint(x: 0.27558 * width, y: 0.03571 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.60714 * width, y: 0.03571 * height))
        strokePath2.addCurve(
            to: CGPoint(x: 0.78757 * width, y: 0.05582 * height),
            control1: CGPoint(x: 0.70061 * width, y: 0.03571 * height),
            control2: CGPoint(x: 0.74735 * width, y: 0.03571 * height)
        )
        strokePath2.addCurve(
            to: CGPoint(x: 0.9119 * width, y: 0.1881 * height),
            control1: CGPoint(x: 0.82779 * width, y: 0.07593 * height),
            control2: CGPoint(x: 0.85582 * width, y: 0.11332 * height)
        )
        strokePath2.addLine(to: CGPoint(x: 0.94048 * width, y: 0.22619 * height))
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
        path.addPath(strokePath2.strokedPath(StrokeStyle(
            lineWidth: 0.07143 * width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4
        )))
        return path
    }
}
