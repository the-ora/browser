import SwiftUI

enum TrackingEdge {
    case left
    case right
    case top
    case bottom
}

struct GlobalMouseTrackingArea: NSViewRepresentable {
    @Binding var mouseEntered: Bool
    let edge: TrackingEdge
    let padding: CGFloat
    let slack: CGFloat

    init(
        mouseEntered: Binding<Bool>,
        edge: TrackingEdge,
        padding: CGFloat = 40,
        slack: CGFloat = 8
    ) {
        self._mouseEntered = mouseEntered
        self.edge = edge
        self.padding = padding
        self.slack = slack
    }

    func makeNSView(context: Context) -> NSView {
        let view = GlobalTrackingStrip(edge: edge, padding: padding, slack: slack)

        view.onHoverChange = { hovering in
            self.mouseEntered = hovering
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let strip = nsView as? GlobalTrackingStrip {
            strip.edge = edge
            strip.padding = padding
            strip.slack = slack
        }
    }
}

private final class GlobalTrackingStrip: NSView {
    var edge: TrackingEdge
    var padding: CGFloat
    var slack: CGFloat

    #if DEBUG
        private var debugWindow: NSWindow?
        func showDebugOverlay(for screenRect: NSRect) {
            debugWindow?.orderOut(nil)
            debugWindow = nil

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

            let overlay = NSView(frame: win.contentView!.bounds)
            overlay.wantsLayer = true
            overlay.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
            overlay.layer?.borderColor = NSColor.systemBlue.cgColor
            overlay.layer?.borderWidth = 2
            win.contentView?.addSubview(overlay)

            win.orderFrontRegardless()
            debugWindow = win
        }
    #endif

    var onHoverChange: ((Bool) -> Void)?
    private var hoverTracker: GlobalHoverTracker?

    init(edge: TrackingEdge, padding: CGFloat = 40, slack: CGFloat = 8) {
        self.edge = edge
        self.padding = padding
        self.slack = slack
        super.init(frame: .zero)
        self.hoverTracker = GlobalHoverTracker(view: self)
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
}

private class GlobalHoverTracker {
    typealias LocalMonitorToken = Any

    private var localMonitor: LocalMonitorToken?
    private var armed = false
    private var isInside = false

    weak var view: GlobalTrackingStrip?

    init(view: GlobalTrackingStrip? = nil) {
        self.view = view
    }

    func startTracking(completion: @escaping (Bool) -> Void) {
        guard localMonitor == nil else { return }

        var handler: ((NSEvent) -> Void)!

        handler = { [weak self] _ in
            guard let self else { return }
            guard let view = self.view else { return }
            guard let window = view.window else { return }

            let mouse = NSEvent.mouseLocation
            let screenRect = window.convertToScreen(
                view.convert(view.bounds, to: nil)
            )

            let basePadding: CGFloat = armed ? view.padding : 0
            let offset: CGFloat = -1

            // Create extended band based on edge
            let band = switch view.edge {
            case .left:
                NSRect(
                    x: screenRect.minX - offset - basePadding,
                    y: screenRect.minY - view.slack,
                    width: basePadding,
                    height: screenRect.height + 2 * view.slack
                )
            case .right:
                NSRect(
                    x: screenRect.maxX + offset,
                    y: screenRect.minY - view.slack,
                    width: basePadding,
                    height: screenRect.height + 2 * view.slack
                )
            case .top:
                NSRect(
                    x: screenRect.minX - view.slack,
                    y: screenRect.maxY + offset,
                    width: screenRect.width + 2 * view.slack,
                    height: basePadding
                )
            case .bottom:
                NSRect(
                    x: screenRect.minX - view.slack,
                    y: screenRect.minY - offset - basePadding,
                    width: screenRect.width + 2 * view.slack,
                    height: basePadding
                )
            }

            let insideBase = screenRect.contains(mouse)
            let inBand = band.contains(mouse)
            let effective = insideBase || inBand

//            #if DEBUG
//            DispatchQueue.main.async {
//                view.showDebugOverlay(for: band)
//            }
//            #endif

            if effective != isInside {
                isInside = effective
                armed = effective
                if Thread.isMainThread {
                    completion(effective)
                } else {
                    DispatchQueue.main.async { completion(effective) }
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved]
        ) { event in
            handler(event)
            return event
        }
    }

    func stop() {
        if let local = localMonitor { NSEvent.removeMonitor(local) }
        localMonitor = nil
        isInside = false
    }
}
