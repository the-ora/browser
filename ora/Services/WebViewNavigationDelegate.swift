import WebKit
import AppKit
import SwiftUI

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    weak var tab: BrowserTab? // Weak reference to BrowserTab
    private var retryCount = 0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 0.5 // 500ms delay between retries
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
        onURLChange?(webView.url)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)
        onTitleChange?(webView.title)
        onURLChange?(webView.url)
        
        // Inject performance optimization script
        let script = """
        // Force GPU rendering for smooth scrolling
        document.body.style.transform = 'translateZ(0)';
        document.body.style.backfaceVisibility = 'hidden';
        
        // Enable hardware acceleration for elements
        const acceleratedElements = document.querySelectorAll('div, img, video, canvas');
        acceleratedElements.forEach(el => {
            el.style.transform = 'translateZ(0)';
            el.style.backfaceVisibility = 'hidden';
        });
        """
        
        // Start the snapshot process after a short delay to allow rendering
        takeSnapshotAfterLoad(webView)
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    private func takeSnapshotAfterLoad(_ webView: WKWebView) {
        if retryCount < maxRetries && webView.isLoading {
            // If still loading, retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.takeSnapshotAfterLoad(webView)
            }
            retryCount += 1
            return
        }
        
        // If loading is complete or max retries reached
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: 1) // Capture top row
        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self = self else { return }
            if let image = image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let color = self.extractDominantColor(from: cgImage)
                DispatchQueue.main.async {
                    if let tab = self.tab, let color = color {
                        tab.backgroundColor = Color(nsColor: color)
                        print("Extracted color: \(color)") // Debug log
                        print("Tab background color: \(Color(nsColor: color))") // Debug log
                    } else {
                        print("Failed to extract color from snapshot")
                    }
                }
            } else {
                print("Snapshot failed with error: \(String(describing: error))")
            }
            self.retryCount = 0 // Reset retry count
        }
    }
    
    private func extractDominantColor(from cgImage: CGImage) -> NSColor? {
        let width = cgImage.width
        let height = cgImage.height
        if width == 0 || height == 0 { 
            print("Invalid image dimensions: \(width)x\(height)")
            return nil 
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: 1, // Only process the top row
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4 * width,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else { 
            print("Failed to create context")
            return nil 
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: 1))
        
        guard let data = context.data else { 
            print("Failed to get pixel data")
            return nil 
        }
        let pixelData = data.bindMemory(to: UInt32.self, capacity: width)
        
        var redTotal: CGFloat = 0
        var greenTotal: CGFloat = 0
        var blueTotal: CGFloat = 0
        var count = 0
        
        for x in 0..<width {
            let pixel = pixelData[x]
            let red = CGFloat((pixel >> 16) & 0xFF) / 255.0
            let green = CGFloat((pixel >> 8) & 0xFF) / 255.0
            let blue = CGFloat(pixel & 0xFF) / 255.0
            redTotal += red
            greenTotal += green
            blueTotal += blue
            count += 1
        }
        
        if count > 0 {
            let avgRed = redTotal / CGFloat(count)
            let avgGreen = greenTotal / CGFloat(count)
            let avgBlue = blueTotal / CGFloat(count)
            return NSColor(red: avgRed, green: avgGreen, blue: avgBlue, alpha: 1.0)
        }
        print("No valid pixels found")
        return nil
    }
}