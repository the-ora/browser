import WebKit
import AppKit
import SwiftUI

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    weak var tab: BrowserTab?
    private var retryCount = 0
    private let maxRetries = 5
    private let retryDelay: TimeInterval = 1.0
    
    override init() {
        super.init()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
        onURLChange?(webView.url)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)
        onTitleChange?(webView.title)
        onURLChange?(webView.url)
        
        // Start the snapshot process after a short delay to allow rendering
        takeSnapshotAfterLoad(webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    private func takeSnapshotAfterLoad(_ webView: WKWebView) {
        if retryCount < maxRetries && (webView.isLoading || webView.bounds.width == 0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.takeSnapshotAfterLoad(webView)
            }
            retryCount += 1
            return
        }
        
        guard !webView.isLoading, webView.bounds.width > 0 else {
            retryCount = 0
            return
        }
        
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: 24)
        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self = self else { return }
            if let image = image {
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let color = self.extractDominantColor(from: cgImage)
                    DispatchQueue.main.async {
                        if let tab = self.tab {
                            if let color = color {
                                tab.backgroundColor = Color(nsColor: color)
                            } else {
                                tab.backgroundColor = Color(nsColor: NSColor.black)
                            }
                        } else {
                            print("Tab reference is nil during color set")
                        }
                    }
                } else {
                    print("Failed to get cgImage from snapshot")
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
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            print("Failed to create context")
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let data = context.data else {
            print("Failed to get pixel data")
            return nil
        }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        
        let samplePoints = [
            (0, 0),
            (Int(width) - 1, 0),
            (0, Int(height) - 1),
            (Int(width) - 1, Int(height) - 1)
        ]
        
        var colors: [NSColor] = []
        
        for (x, y) in samplePoints {
            let offset = 4 * (y * Int(width) + x)
            let red = CGFloat(pixels[offset]) / 255.0
            let green = CGFloat(pixels[offset + 1]) / 255.0
            let blue = CGFloat(pixels[offset + 2]) / 255.0
            let alpha = CGFloat(pixels[offset + 3]) / 255.0
            let color = NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
            colors.append(color)
        }
        
        return findMostCommonColor(colors)
    }
    
    private func findMostCommonColor(_ colors: [NSColor]) -> NSColor? {
        var colorCounts: [String: (NSColor, Int)] = [:]
        
        for color in colors {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let key = "\(Int(red * 255))-\(Int(green * 255))-\(Int(blue * 255))"
            
            if let (_, count) = colorCounts[key] {
                colorCounts[key] = (color, count + 1)
            } else {
                colorCounts[key] = (color, 1)
            }
        }
        
        let mostCommon = colorCounts.max(by: { $0.value.1 < $1.value.1 })
        return mostCommon?.value.0 ?? NSColor.white
    }
}