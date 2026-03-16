import AppKit
import SwiftUI

final class BrowserPageHostView: NSView {
    private(set) weak var hostedContentView: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        autoresizesSubviews = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func host(contentView newContentView: NSView?) {
        let previousContentView = hostedContentView
        let isSameContentView = previousContentView === newContentView

        if isSameContentView, newContentView?.superview === self {
            return
        }

        let shouldRestoreFirstResponder = shouldTransferFirstResponder(from: previousContentView)

        if isSameContentView {
            hostedContentView = nil
        } else {
            detachHostedContentView()
        }

        guard let newContentView else {
            refreshHostingLayout()
            return
        }

        configure(contentView: newContentView)

        if let previousHost = newContentView.superview as? BrowserPageHostView,
           previousHost !== self
        {
            previousHost.releaseHostedContentView(newContentView)
        }

        if newContentView.superview !== self {
            if newContentView.superview != nil {
                newContentView.removeFromSuperview()
            }
            addSubview(newContentView)
        }

        newContentView.frame = bounds
        hostedContentView = newContentView

        needsLayout = true
        layoutSubtreeIfNeeded()
        newContentView.needsLayout = true
        newContentView.layoutSubtreeIfNeeded()
        newContentView.needsDisplay = true
        displayIfNeeded()

        if shouldRestoreFirstResponder {
            window?.makeFirstResponder(newContentView)
        }
    }

    override func layout() {
        super.layout()
        hostedContentView?.frame = bounds
    }

    private func configure(contentView: NSView) {
        contentView.wantsLayer = true
        contentView.autoresizingMask = [.width, .height]
        contentView.layer?.isOpaque = true
        contentView.layer?.drawsAsynchronously = true
    }

    private func detachHostedContentView() {
        guard let hostedContentView else {
            return
        }

        if hostedContentView.superview === self {
            hostedContentView.removeFromSuperview()
        }

        self.hostedContentView = nil
    }

    private func releaseHostedContentView(_ contentView: NSView) {
        guard hostedContentView === contentView else {
            return
        }

        detachHostedContentView()
        refreshHostingLayout()
    }

    private func refreshHostingLayout() {
        needsLayout = true
        layoutSubtreeIfNeeded()
        displayIfNeeded()
    }

    private func shouldTransferFirstResponder(from previousContentView: NSView?) -> Bool {
        guard let previousContentView,
              let firstResponder = window?.firstResponder as? NSView
        else {
            return false
        }

        return firstResponder === previousContentView || firstResponder.isDescendant(of: previousContentView)
    }
}

struct BrowserPageView: NSViewRepresentable {
    let page: BrowserPage
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var privacyMode: PrivacyMode

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tabManager: tabManager,
            historyManager: historyManager,
            privacyMode: privacyMode
        )
    }

    func makeNSView(context: Context) -> BrowserPageHostView {
        let hostView = BrowserPageHostView(frame: .zero)
        let contentView = page.contentView
        context.coordinator.update(page: page, contentView: contentView)
        hostView.host(contentView: contentView)
        return hostView
    }

    func updateNSView(_ nsView: BrowserPageHostView, context: Context) {
        let contentView = page.contentView
        context.coordinator.update(page: page, contentView: contentView)
        nsView.host(contentView: contentView)
    }

    final class Coordinator: NSObject {
        weak var tabManager: TabManager?
        weak var historyManager: HistoryManager?
        weak var privacyMode: PrivacyMode?
        private weak var page: BrowserPage?
        private var mouseEventMonitor: Any?
        private weak var contentView: NSView?

        init(
            tabManager: TabManager?,
            historyManager: HistoryManager?,
            privacyMode: PrivacyMode
        ) {
            self.tabManager = tabManager
            self.historyManager = historyManager
            self.privacyMode = privacyMode
            super.init()
            startMouseEventMonitoring()
        }

        deinit {
            if let monitor = mouseEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func update(page: BrowserPage, contentView: NSView) {
            self.page = page
            self.contentView = contentView
        }

        private func startMouseEventMonitoring() {
            mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
                guard let self,
                      let page = self.page,
                      let contentView = self.contentView,
                      self.isEventInContentView(event, contentView: contentView)
                else {
                    return event
                }

                switch event.buttonNumber {
                case 2:
                    self.handleMiddleClick(at: event.locationInWindow, contentView: contentView, page: page)
                    return nil
                case 3:
                    if page.canGoBack {
                        DispatchQueue.main.async {
                            page.goBack()
                        }
                    }
                    return nil
                case 4:
                    if page.canGoForward {
                        DispatchQueue.main.async {
                            page.goForward()
                        }
                    }
                    return nil
                default:
                    return event
                }
            }
        }

        private func handleMiddleClick(at location: NSPoint, contentView: NSView, page: BrowserPage) {
            let locationInContentView = contentView.convert(location, from: nil)
            guard locationInContentView.x.isFinite,
                  locationInContentView.y.isFinite,
                  locationInContentView.x >= 0,
                  locationInContentView.y >= 0
            else {
                return
            }

            let script = """
            (function() {
                var element = document.elementFromPoint(\(locationInContentView.x), \(locationInContentView.y));
                while (element && element.tagName !== 'A') {
                    element = element.parentElement;
                }
                return element ? element.href : null;
            })();
            """

            page.evaluateJavaScript(script) { [weak self, weak page] result, error in
                guard error == nil,
                      page != nil,
                      let urlString = result as? String,
                      let url = URL(string: urlString),
                      let tabManager = self?.tabManager,
                      let historyManager = self?.historyManager,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                else {
                    return
                }

                DispatchQueue.main.async {
                    _ = tabManager.openTab(
                        url: url,
                        historyManager: historyManager,
                        focusAfterOpening: false,
                        isPrivate: self?.privacyMode?.isPrivate ?? false
                    )
                }
            }
        }

        private func isEventInContentView(_ event: NSEvent, contentView: NSView) -> Bool {
            let locationInWindow = event.locationInWindow
            let locationInContentView = contentView.convert(locationInWindow, from: nil)
            return contentView.bounds.contains(locationInContentView)
        }
    }
}
