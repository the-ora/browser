import SwiftUI

struct MouseTrackingArea: NSViewRepresentable {
    @Binding var mouseEntered: Bool

    func makeNSView(context: Context) -> NSView {
        let view = TrackingStrip()

        /// No Need To Pass We Can handle it nicely with closures
        view.onHoverChange = { hovering in
            self.mouseEntered = hovering
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TrackingStrip: NSView {
    #if DEBUG
        private var debugWindow: NSWindow?
        func showDebugOverlay(for screenRect: NSRect) {
            debugWindow?.orderOut(nil)
            debugWindow = nil

            /// Make a borderless, transparent window at the rect
            let win = NSWindow(
                contentRect: screenRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.level = .statusBar

            /// colored view
            let overlay = NSView(frame: win.contentView!.bounds)
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.2).cgColor
            overlay.layer?.borderColor = NSColor.systemGreen.cgColor
            overlay.layer?.borderWidth = 2
            win.contentView?.addSubview(overlay)

            win.orderFrontRegardless()
            debugWindow = win
        }
    #endif

    var onHoverChange: ((Bool) -> Void)?

    private var hoverTracker: HoverTracker?

    init() {
        super.init(frame: .zero)
        self.hoverTracker = HoverTracker(view: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { hoverTracker?.stop() }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit {
        hoverTracker?.stop()
    }

    override func viewDidMoveToWindow() {
        if window == nil {
            hoverTracker?.stop()
        } else {
            hoverTracker?.startTracking { [weak self] inside in
                guard let self else { return }
                self.onHoverChange?(inside)
            }
        }
        super.viewDidMoveToWindow()
    }

    class HoverTracker {
        typealias LocalMonitorToken  = Any

        private var localMonitor: LocalMonitorToken?

        private var armed = false
        private var isInside = false

        weak var view: TrackingStrip?

        /// Maybe Configurable inside settings or tuned to liking?
        let padding: CGFloat = 40
        let verticalSlack: CGFloat = 8    // extra Y tolerance

        init(
            view: TrackingStrip? = nil
        ) {
            self.view = view
        }

        func startTracking(completion: @escaping (Bool) -> Void) {
            guard localMonitor == nil else { return }

            var handler: ((NSEvent) -> Void)!

            handler = { [weak self] _ in
                guard let self else { return }
                guard let view = self.view else { return }
                guard let window = view.window else { return }

                /// Global Screen Coordinates
                let mouse = NSEvent.mouseLocation

                /// This is where the view is
                let screenRect = window.convertToScreen(view.convert(view.bounds, to: nil))

                /*
                 Maybe wanna let a bit of the left allow the sidebar to show:
                 Move offset +
                 Also Make baseWidth negation something larger
                 */
                /// If we are showing the sidebar THEN we grow the size
                let baseWidth: CGFloat = armed ? padding : 0
                /// - goes to right, + goes to left, I like -1
                let offset: CGFloat = -1

                let leftBand = NSRect(
                    x: screenRect.minX - offset - baseWidth,
                    y: screenRect.minY - verticalSlack,
                    width: baseWidth,
                    height: screenRect.height + 2 * verticalSlack
                )

                let insideBase  = screenRect.contains(mouse)
                let inLeftBand  = leftBand.contains(mouse)

                let effective   = insideBase || inLeftBand

//                #if DEBUG
//                /// UNCOMMENT IF WANNA SEE RECT GETTING HIDDEN/SHOWN
//                DispatchQueue.main.async {
//                    view.showDebugOverlay(for: leftBand)
//                }
//                #endif

                if effective != isInside {
                    isInside = effective
                    armed = effective
                    if Thread.isMainThread { completion(effective) }
                    else { DispatchQueue.main.async { completion(effective) } }
                }
            }

            localMonitor  = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in handler(event)
                return event
            }
        }

        func stop() {
            if let local = localMonitor { NSEvent.removeMonitor(local) }
            localMonitor = nil
            isInside = false
        }
    }
}
