import AppKit
import SwiftUI

struct BrowserPageView: NSViewRepresentable {
    let page: BrowserPage
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var privacyMode: PrivacyMode

    func makeCoordinator() -> Coordinator {
        Coordinator(
            page: page,
            tabManager: tabManager,
            historyManager: historyManager,
            privacyMode: privacyMode
        )
    }

    func makeNSView(context: Context) -> NSView {
        let wrapperView = NSView()
        wrapperView.wantsLayer = true
        wrapperView.autoresizesSubviews = true

        let contentView = page.contentView
        contentView.autoresizingMask = [.width, .height]
        contentView.layer?.isOpaque = true
        contentView.layer?.drawsAsynchronously = true
        context.coordinator.setupMouseEventMonitoring(for: contentView)
        wrapperView.addSubview(contentView)
        contentView.frame = wrapperView.bounds

        return wrapperView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator: NSObject {
        private let page: BrowserPage
        weak var tabManager: TabManager?
        weak var historyManager: HistoryManager?
        weak var privacyMode: PrivacyMode?
        private var mouseEventMonitor: Any?
        private weak var contentView: NSView?

        init(
            page: BrowserPage,
            tabManager: TabManager?,
            historyManager: HistoryManager?,
            privacyMode: PrivacyMode
        ) {
            self.page = page
            self.tabManager = tabManager
            self.historyManager = historyManager
            self.privacyMode = privacyMode
        }

        deinit {
            if let monitor = mouseEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func setupMouseEventMonitoring(for contentView: NSView) {
            self.contentView = contentView

            mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
                guard let self,
                      let contentView = self.contentView,
                      self.isEventInContentView(event, contentView: contentView)
                else {
                    return event
                }

                switch event.buttonNumber {
                case 2:
                    self.handleMiddleClick(at: event.locationInWindow, contentView: contentView)
                    return nil
                case 3:
                    if self.page.canGoBack {
                        DispatchQueue.main.async {
                            self.page.goBack()
                        }
                    }
                    return nil
                case 4:
                    if self.page.canGoForward {
                        DispatchQueue.main.async {
                            self.page.goForward()
                        }
                    }
                    return nil
                default:
                    return event
                }
            }
        }

        private func handleMiddleClick(at location: NSPoint, contentView: NSView) {
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

            self.page.evaluateJavaScript(script) { [weak self] result, error in
                guard error == nil,
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
