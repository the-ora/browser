import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let isSidebarHidden: Bool
    let isFloatingSidebar: Bool
    @Binding var isFullscreen: Bool

    // Store original button frames to restore them later
    private static var originalButtonFrames: [NSWindow.ButtonType: NSRect] = [:]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: WindowAccessor
        var observers: [Any] = []

        init(_ parent: WindowAccessor) {
            self.parent = parent
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
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            isFullscreen = window.styleMask.contains(.fullScreen)

            let coordinator = context.coordinator

            let enterObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: window,
                queue: nil,
                using: coordinator.didEnterFullScreen
            )

            let exitObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: window,
                queue: nil,
                using: coordinator.didExitFullScreen
            )

            coordinator.observers = [enterObserver, exitObserver]
            updateTrafficLights(for: window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        updateTrafficLights(for: window)
    }

    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        for observer in coordinator.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func updateTrafficLights(for window: NSWindow) {
        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(buttonType) else { continue }

            // Store original frame if we haven't already
            if WindowAccessor.originalButtonFrames[buttonType] == nil {
                WindowAccessor.originalButtonFrames[buttonType] = button.frame
            }

            if isFloatingSidebar, !isFullscreen {
                if let originalFrame = WindowAccessor.originalButtonFrames[buttonType] {
                    var newFrame = originalFrame
                    newFrame.origin.y -= 12
                    newFrame.origin.x += 16
                    button.frame = newFrame
                }
                button.isHidden = false
            } else {
                // Restore original position
                if let originalFrame = WindowAccessor.originalButtonFrames[buttonType] {
                    button.frame = originalFrame
                }

                if isFullscreen || (!isSidebarHidden && !isFullscreen) {
                    button.isHidden = false
                } else {
                    button.isHidden = true
                }
            }
        }
    }
}
