import WebKit

class OraWebView: WKWebView {
    struct FloatingSidebarInfo {
        let isOnLeft: Bool
        let widthFraction: CGFloat
    }

    /// Set from `BrowserView` when the floating sidebar appears/disappears.
    /// Checked on every `mouseMoved` to prevent web-content hover/cursor
    /// changes behind the sidebar overlay.
    nonisolated(unsafe) static var floatingSidebarInfo: FloatingSidebarInfo?

    override func mouseMoved(with event: NSEvent) {
        if let info = Self.floatingSidebarInfo, bounds.width > 0 {
            let location = convert(event.locationInWindow, from: nil)
            let sidebarWidth = bounds.width * info.widthFraction
            let blocked = info.isOnLeft
                ? location.x <= sidebarWidth
                : location.x >= bounds.width - sidebarWidth
            if blocked {
                NSCursor.arrow.set()
                return
            }
        }
        super.mouseMoved(with: event)
    }
}
