import SwiftUI

struct SidebarMouseTrackingArea: NSViewRepresentable {
    @Binding var mouseEntered: Bool
    var sidebarPosition: SidebarPosition = .primary

    func makeNSView(context: Context) -> NSView {
        let view = TrackingStrip(sidebarPosition: sidebarPosition)

        view.onHoverChange = { hovering in
            self.mouseEntered = hovering
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let strip = nsView as? TrackingStrip {
            strip.sidebarPosition = sidebarPosition
        }
    }
}

private final class TrackingStrip: NSView {
    var sidebarPosition: SidebarPosition = .primary

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

    init(sidebarPosition: SidebarPosition = .primary) {
        self.sidebarPosition = sidebarPosition
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
        typealias LocalMonitorToken = Any

        private var localMonitor: LocalMonitorToken?

        private var armed = false
        private var isInside = false

        weak var view: TrackingStrip?

        let padding: CGFloat = 40
        let verticalSlack: CGFloat = 8

        init(view: TrackingStrip? = nil) {
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

                let baseWidth: CGFloat = armed ? padding : 0
                let offset: CGFloat = -1

                // Create band based on sidebar position
                let band = if view.sidebarPosition == .primary {
                    // Left side band
                    NSRect(
                        x: screenRect.minX - offset - baseWidth,
                        y: screenRect.minY - verticalSlack,
                        width: baseWidth,
                        height: screenRect.height + 2 * verticalSlack
                    )
                } else {
                    // Right side band
                    NSRect(
                        x: screenRect.maxX + offset,
                        y: screenRect.minY - verticalSlack,
                        width: baseWidth,
                        height: screenRect.height + 2 * verticalSlack
                    )
                }

                let insideBase = screenRect.contains(mouse)
                let inBand = band.contains(mouse)

                let effective = insideBase || inBand

//                #if DEBUG
//                DispatchQueue.main.async {
//                    view.showDebugOverlay(for: band)
//                }
//                #endif

                if effective != isInside {
                    isInside = effective
                    armed = effective
                    if Thread.isMainThread { completion(effective) }
                    else { DispatchQueue.main.async { completion(effective) } }
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
}
