import AppKit
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
  let webView: WKWebView

  func makeCoordinator() -> Coordinator {
    return Coordinator()
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
  }
}
