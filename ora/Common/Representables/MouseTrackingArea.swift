import SwiftUI

struct MouseTrackingArea: NSViewRepresentable {
    @Binding var mouseEntered: Bool
    var xExit: CGFloat?
    var yExit: CGFloat?

    func makeNSView(context: Context) -> NSView {
        let view = TrackingStrip(xExit: xExit, yExit: yExit)

        /// No Need To Pass We Can handle it nicely with closures
        view.onHoverChange = { hovering in
            self.mouseEntered = hovering
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TrackingStrip: NSView {
    var onHoverChange: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private let xExit: CGFloat?
    private let yExit: CGFloat?
    private var globalTracker: GlobalTracker?

    init(xExit: CGFloat?, yExit: CGFloat?) {
        self.xExit = xExit
        self.yExit = yExit
        super.init(frame: .zero)
        self.globalTracker = GlobalTracker(view: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { globalTracker?.stop() }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit { globalTracker?.stop() }

    override func viewDidMoveToWindow() {
        if window == nil {
            globalTracker?.stop()
        } else {
            globalTracker?.startTracking { [weak self] inside in
                guard let self else { return }
                self.onHoverChange?(inside)
            }
        }
        super.viewDidMoveToWindow()
    }

    class GlobalTracker {
        var isInside: Bool = false
        var localTracker: Any?
        var globalTracker: Any?
        weak var view: NSView?

        let leftPadding: CGFloat = 30     // how far left still counts
        let verticalSlack: CGFloat = 8    // extra Y tolerance

        init(
            view: NSView? = nil
        ) {
            self.view = view
        }

        func startTracking(completion: @escaping (Bool) -> Void) {
            let handler: (NSEvent) -> Void = { [weak self] _ in
                guard let self else { return }
                guard let view = self.view else { return }

                let screenLocation = NSEvent.mouseLocation /// Global Screen Coordinates
                /// This is where the view is
                let screenRect = view.window?.convertToScreen(view.convert(view.bounds, to: nil)) ?? .zero

                let inside = screenRect.contains(screenLocation)

                // Build a thin rect just left of the view
                var leftBand = screenRect
                leftBand.origin.x = screenRect.minX - leftPadding
                leftBand.size.width = leftPadding
                leftBand = leftBand.insetBy(dx: 0, dy: -verticalSlack)

                // If we're not truly inside, allow the left band
                let inLeftBand = leftBand.contains(screenLocation)
                let effectiveInside = inside || inLeftBand

                if effectiveInside != self.isInside {
                    self.isInside = effectiveInside
                    if Thread.isMainThread { completion(effectiveInside) }
                    else { DispatchQueue.main.async { completion(effectiveInside) } }
                }
            }

            globalTracker = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: handler)
            localTracker  = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { e in handler(e)
                return e
            }
        }

        func stop() {
            if let g = globalTracker { NSEvent.removeMonitor(g) }
            if let l = localTracker { NSEvent.removeMonitor(l) }
            globalTracker = nil
            localTracker = nil
            isInside = false
        }
    }
}
