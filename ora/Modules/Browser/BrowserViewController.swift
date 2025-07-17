import AppKit
import SwiftUI

// MARK: - BrowserViewController
struct BrowserViewController: View {
  @StateObject private var tabManager = TabManager()
  @Environment(\.colorScheme) var colorScheme
  @State private var columnVisibility: NavigationSplitViewVisibility = .all  // Changed to NavigationSplitViewVisibility
  @EnvironmentObject private var appState: AppState
  @State private var isFullscreen = false

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {  // Bind columnVisibility
      SidebarView()
        .transition(.move(edge: .leading).combined(with: .opacity))
        .toolbar(removing: .sidebarToggle)
    } detail: {
      VStack(alignment: .leading, spacing: 0) {
        if let selectedTab = tabManager.selectedTab {
          URLBar(tab: selectedTab, columnVisibility: $columnVisibility)

          WebView(webView: selectedTab.webView)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          Text("No tab selected")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    //   .background(VisualEffectView())
      .cornerRadius(isFullscreen && columnVisibility != .all ? 0 : 8)
      .padding(isFullscreen && columnVisibility != .all ? 0 : 6)
      .ignoresSafeArea(.all)
    }
    .navigationSplitViewStyle(.balanced)  // Ensure balanced style for macOS
    .background(
      WindowAccessor(isSidebarVisible: columnVisibility == .all, isFullscreen: $isFullscreen)
    )
    .environmentObject(tabManager)
    .overlay {
      if appState.showLauncher {
        LauncherView()
      }
    }
  }
}

struct VisualEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.state = .active
    view.material = .underWindowBackground
    view.isEmphasized = true
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    // No updates needed
  }
}

struct WindowAccessor: NSViewRepresentable {
  let isSidebarVisible: Bool
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false

        self.isFullscreen = window.styleMask.contains(.fullScreen)

        let coord = context.coordinator

        let enterObs = NotificationCenter.default.addObserver(
          forName: NSWindow.didEnterFullScreenNotification, object: window, queue: nil,
          using: coord.didEnterFullScreen)

        let exitObs = NotificationCenter.default.addObserver(
          forName: NSWindow.didExitFullScreenNotification, object: window, queue: nil,
          using: coord.didExitFullScreen)

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
    coordinator.observers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private func updateTrafficLights(window: NSWindow) {
    let shouldHide = !self.isSidebarVisible && !self.isFullscreen
    window.standardWindowButton(.closeButton)?.isHidden = shouldHide
    window.standardWindowButton(.miniaturizeButton)?.isHidden = shouldHide
    window.standardWindowButton(.zoomButton)?.isHidden = shouldHide
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.titlebarSeparatorStyle = .none
    window.isOpaque = false
  }
}

#Preview {
  BrowserViewController()
}
