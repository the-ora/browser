import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    @Binding var isFullscreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: WindowAccessor
        var observers: [Any] = []

        init(_ parent: WindowAccessor) {
            self.parent = parent
        }

        @objc func willEnterFullScreenNotification(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            parent.isFullscreen = true
            parent.updateTrafficLights(for: window)
        }

        @objc func willExitFullScreenNotification(_ notification: Notification) {
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
                forName: NSWindow.willEnterFullScreenNotification,
                object: window,
                queue: nil,
                using: coordinator.willEnterFullScreenNotification
            )

            let exitObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willExitFullScreenNotification,
                object: window,
                queue: nil,
                using: coordinator.willExitFullScreenNotification
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
        for type in [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ] {
            guard let button = window.standardWindowButton(type) else { continue }
            button.animator().isHidden = !isFullscreen
        }
    }
}
