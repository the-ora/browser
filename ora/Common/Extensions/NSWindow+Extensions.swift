import AppKit
import Foundation

extension NSWindow {
    /// Toggles the window between maximized (filling the visible screen) and restored states.
    /// Uses smooth animations and respects the menu bar and dock.
    func toggleMaximized() {
        // Get the screen's visible frame (excludes menu bar and dock)
        guard let screen = self.screen else { return }
        let screenFrame = screen.visibleFrame

        // Check if window is already maximized (with some tolerance for small differences)
        let currentFrame = self.frame
        let tolerance: CGFloat = 10
        let isMaximized = abs(currentFrame.size.width - screenFrame.size.width) < tolerance &&
            abs(currentFrame.size.height - screenFrame.size.height) < tolerance &&
            abs(currentFrame.origin.x - screenFrame.origin.x) < tolerance &&
            abs(currentFrame.origin.y - screenFrame.origin.y) < tolerance

        if isMaximized {
            // If already maximized, restore to a reasonable size in center
            let restoredWidth: CGFloat = 1440
            let restoredHeight: CGFloat = 900
            let newFrame = NSRect(
                x: screenFrame.midX - restoredWidth / 2,
                y: screenFrame.midY - restoredHeight / 2,
                width: restoredWidth,
                height: restoredHeight
            )
            self.setFrame(newFrame, display: true, animate: true)
        } else {
            // Maximize to fill the visible screen area
            self.setFrame(screenFrame, display: true, animate: true)
        }
    }

    /// Returns true if the window is currently maximized to fill the visible screen area
    var isMaximized: Bool {
        guard let screen = self.screen else { return false }
        let screenFrame = screen.visibleFrame
        let currentFrame = self.frame
        let tolerance: CGFloat = 10

        return abs(currentFrame.size.width - screenFrame.size.width) < tolerance &&
            abs(currentFrame.size.height - screenFrame.size.height) < tolerance &&
            abs(currentFrame.origin.x - screenFrame.origin.x) < tolerance &&
            abs(currentFrame.origin.y - screenFrame.origin.y) < tolerance
    }

    /// Maximizes the window to fill the visible screen area
    func maximize() {
        guard let screen = self.screen else { return }
        let screenFrame = screen.visibleFrame
        self.setFrame(screenFrame, display: true, animate: true)
    }

    /// Restores the window to a default size and centers it on the screen
    func restoreToDefaultSize() {
        guard let screen = self.screen else { return }
        let screenFrame = screen.visibleFrame
        let restoredWidth: CGFloat = 1440
        let restoredHeight: CGFloat = 900
        let newFrame = NSRect(
            x: screenFrame.midX - restoredWidth / 2,
            y: screenFrame.midY - restoredHeight / 2,
            width: restoredWidth,
            height: restoredHeight
        )
        self.setFrame(newFrame, display: true, animate: true)
    }
}
