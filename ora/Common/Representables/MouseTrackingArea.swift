import SwiftUI

struct MouseTrackingArea: NSViewRepresentable {
    @Binding var mouseEntered: Bool
    var xExit: CGFloat?
    var yExit: CGFloat?

    func makeNSView(context: Context) -> NSView {
        TrackingStrip(mouseEntered: _mouseEntered, xExit: xExit, yExit: yExit)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TrackingStrip: NSView {
    @Binding var mouseEntered: Bool
    private var trackingArea: NSTrackingArea?
    private let xExit: CGFloat?
    private let yExit: CGFloat?

    init(mouseEntered: Binding<Bool>, xExit: CGFloat?, yExit: CGFloat?) {
        _mouseEntered = mouseEntered
        self.xExit = xExit
        self.yExit = yExit
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        mouseEntered = true
    }

    override func mouseExited(with event: NSEvent) {
        let global = event.locationInWindow
        let screenPoint = window?.convertPoint(toScreen: global) ?? global

        // Check if mouse is still inside the sidebar area
        if let win = window {
            let sidebarRect = NSRect(x: 0, y: 0, width: xExit ?? 340, height: win.frame.height)
            if sidebarRect.contains(win.convertFromScreen(NSRect(origin: screenPoint, size: .zero)).origin) {
                return // still inside sidebar zone → don’t close
            }
        }

        mouseEntered = false
    }
}
