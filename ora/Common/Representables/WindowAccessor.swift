import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
  let isSidebarHidden: Bool
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

    @objc func didEnterFullScreen(_ notification: Notification) {
      parent.isFullscreen = true
      if let window = (notification.object as? NSWindow) {
        parent.updateTrafficLights(window: window)
      }
    }

    @objc func didExitFullScreen(_ notification: Notification) {
      parent.isFullscreen = false
      if let window = (notification.object as? NSWindow) {
        parent.updateTrafficLights(window: window)
      }
    }
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()

    DispatchQueue.main.async {
      if let window = view.window {
        self.isFullscreen = window.styleMask.contains(.fullScreen)

        let coord = context.coordinator

        let enterObs = NotificationCenter.default.addObserver(
          forName: NSWindow.didEnterFullScreenNotification,
          object: window,
          queue: nil,
          using: coord.didEnterFullScreen
        )

        let exitObs = NotificationCenter.default.addObserver(
          forName: NSWindow.didExitFullScreenNotification,
          object: window,
          queue: nil,
          using: coord.didExitFullScreen
        )

        coord.observers = [enterObs, exitObs]

        self.updateTrafficLights(window: window)
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let window = nsView.window {
      self.updateTrafficLights(window: window)
    }
  }

  func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.observers.forEach {
      NotificationCenter.default.removeObserver($0)
    }
  }

  private func updateTrafficLights(window: NSWindow) {
    let shouldHide = self.isSidebarHidden && !self.isFullscreen
    window.standardWindowButton(.closeButton)?.isHidden = shouldHide
    window.standardWindowButton(.miniaturizeButton)?.isHidden = shouldHide
    window.standardWindowButton(.zoomButton)?.isHidden = shouldHide
  }
}
