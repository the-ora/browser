import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let isSidebarHidden: Bool
    @Binding var isFloatingSidebar: Bool
    @Binding var isFullscreen: Bool

    // Store original button frames to restore them later
    private static var originalButtonFrames: [NSWindow.ButtonType: NSRect] = [:]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSView {
        var parent: WindowAccessor

        init(_ parent: WindowAccessor) {
            self.parent = parent
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            parent.isFullscreen = window.styleMask.contains(.fullScreen)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterFullScreen(_:)),
                name: NSWindow.didEnterFullScreenNotification,
                object: window
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didExitFullScreen(_:)),
                name: NSWindow.didExitFullScreenNotification,
                object: window
            )

            parent.updateTrafficLights(for: window)
        }

        @objc func didEnterFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            parent.isFullscreen = true
            parent.updateTrafficLights(for: window)
        }

        @objc func didExitFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            parent.isFullscreen = false
            parent.updateTrafficLights(for: window)
        }
    }

    func makeNSView(context: Context) -> NSView {
        return context.coordinator
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        updateTrafficLights(for: window)
    }

    private func updateTrafficLights(for window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(buttonType) else { continue }

                // Store original frame if we haven't already
                if WindowAccessor.originalButtonFrames[buttonType] == nil {
                    WindowAccessor.originalButtonFrames[buttonType] = button.frame
                }

                if let originalFrame = WindowAccessor.originalButtonFrames[buttonType] {
                    if isSidebarHidden, !isFullscreen {
                        // Always offset when sidebar is hidden
                        var newFrame = originalFrame
                        newFrame.origin.x += 8
                        newFrame.origin.y -= 8
                        button.animator().setFrameOrigin(newFrame.origin)
                    } else {
                        // Restore to original frame when visible
                        button.animator().setFrameOrigin(originalFrame.origin)
                    }
                }

                button.animator().isHidden = (isSidebarHidden && !isFloatingSidebar && !isFullscreen)
            }
        }
    }
}
