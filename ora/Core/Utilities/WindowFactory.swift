import AppKit
import SwiftUI

enum WindowFactory {
    static func makeMainWindow(rootView: some View, size: CGSize = CGSize(width: 1440, height: 900)) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}
