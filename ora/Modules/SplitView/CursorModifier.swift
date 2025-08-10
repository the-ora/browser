import SwiftUI

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
}

struct CursorModifier: ViewModifier {
    let cursor: NSCursor

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                Representable(cursor: cursor,
                              frame: proxy.frame(in: .global))
            }
        )
    }

    private class CustomCursorView: NSView {
        var cursor: NSCursor!
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    private struct Representable: NSViewRepresentable {
        let cursor: NSCursor
        let frame: NSRect

        func makeNSView(context: Context) -> NSView {
            let cursorView = CustomCursorView(frame: frame)
            cursorView.cursor = cursor
            return cursorView
        }

        func updateNSView(_ nsView: NSView, context: Context) {}
    }
}
