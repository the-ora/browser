import AppKit
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
  let webView: WKWebView
  @EnvironmentObject var tabManager: TabManager
  @EnvironmentObject var historyManager: HistoryManager
  @EnvironmentObject var downloadManager: DownloadManager

  func makeCoordinator() -> Coordinator {
    return Coordinator(tabManager: tabManager, historyManager: historyManager, downloadManager: downloadManager)
  }

  func makeNSView(context: Context) -> WKWebView {
    webView.uiDelegate = context.coordinator

    webView.autoresizingMask = [.width, .height]
    webView.layer?.isOpaque = true
    webView.layer?.drawsAsynchronously = true

    return webView
  }

  func updateNSView(_ nsView: WKWebView, context: Context) {
    // No update logic needed
  }

  // MARK: - Coordinator for WKUIDelegate
  class Coordinator: NSObject, WKUIDelegate {
    weak var tabManager: TabManager?
    weak var historyManager: HistoryManager?
    weak var downloadManager: DownloadManager?

    init(tabManager: TabManager?, historyManager: HistoryManager?, downloadManager: DownloadManager?) {
      self.tabManager = tabManager
      self.historyManager = historyManager
      self.downloadManager = downloadManager
    }

    func webView(
      _ webView: WKWebView,
      requestMediaCapturePermissionFor origin: WKSecurityOrigin,
      initiatedByFrame frame: WKFrameInfo,
      decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
      decisionHandler(.grant)
    }

    func webView(
      _ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void
    ) {
      let openPanel = NSOpenPanel()
      openPanel.canChooseFiles = true
      openPanel.canChooseDirectories = parameters.allowsDirectories
      openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

      openPanel.begin { result in
        if result == .OK {
          completionHandler(openPanel.urls)
        } else {
          completionHandler(nil)
        }
      }
    }

    // MARK: - Handle target="_blank" and new window requests
    func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      // Handle target="_blank" links and other new window requests
      guard let url = navigationAction.request.url,
            let tabManager = self.tabManager,
            let historyManager = self.historyManager else {
        return nil
      }

      // Create a new tab in the background for the target URL
      DispatchQueue.main.async {
        _ = tabManager.openTab(
          url: url,
          historyManager: historyManager,
          downloadManager: self.downloadManager
        )
      }

      // Return nil to prevent creating a new WebView instance
      // The new tab will handle the navigation
      return nil
    }
  }
}
