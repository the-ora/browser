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

    @MainActor
    class Coordinator {
        var parent: WindowAccessor
        var observationTasks: [Task<Void, Never>] = []

        init(_ parent: WindowAccessor) {
            self.parent = parent
        }

        func didEnterFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            parent.isFullscreen = true
            parent.updateTrafficLights(for: window)
        }

        func didExitFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            parent.isFullscreen = false
            parent.updateTrafficLights(for: window)
        }
    }

    final class WindowView: NSView {
        var onMoveToWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onMoveToWindow?(window)
            }
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = WindowView()
        view.onMoveToWindow = { window in
            isFullscreen = window.styleMask.contains(.fullScreen)

            let coordinator = context.coordinator

            let didEnterFullScreenNotificationTask = Task {
                for await notification in NotificationCenter.default.notifications(
                    named: NSWindow.didEnterFullScreenNotification,
                    object: window
                ) {
                    coordinator.didEnterFullScreen(notification)
                }
            }

            let didExitFullScreenNotificationTask = Task {
                for await notification in NotificationCenter.default.notifications(
                    named: NSWindow.didExitFullScreenNotification,
                    object: window
                ) {
                    coordinator.didExitFullScreen(notification)
                }
            }

            coordinator.observationTasks = [didEnterFullScreenNotificationTask, didExitFullScreenNotificationTask]
            updateTrafficLights(for: window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        updateTrafficLights(for: window)
    }

    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        for task in coordinator.observationTasks {
            task.cancel()
        }
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
