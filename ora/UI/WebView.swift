import SwiftUI
import WebKit

// MARK: - WebView Wrapper for macOS
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        webView.autoresizingMask = [.width, .height]
        
        // Enable hardware acceleration
        webView.layer?.isOpaque = true
        webView.layer?.drawsAsynchronously = true
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No need to reload - the tab handles navigation
    }
} 