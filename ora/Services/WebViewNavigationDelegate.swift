import WebKit
import AppKit
import SwiftUI
let js = """
(function () {
    let lastHref = location.href;
    let lastTitle = document.title;
    let faviconURL = null;
    let sentInitial = false;

    function findFavicon(callback) {
        // 1. Check <link rel="icon">
        const links = document.getElementsByTagName('link');
        for (let i = 0; i < links.length; i++) {
            const rel = links[i].getAttribute('rel');
            if (rel && rel.toLowerCase().includes('icon')) {
                const href = links[i].getAttribute('href');
                if (href) {
                    const resolved = new URL(href, document.baseURI).href;
                    return callback(resolved);
                }
            }
        }

        // 2. Try /favicon.ico
        const fallback = `${location.origin}/favicon.ico`;
        const img = new Image();
        img.onload = () => callback(fallback);
        img.onerror = () =>
            callback(`https://www.google.com/s2/favicons?domain=${location.hostname}`);
        img.src = fallback;
    }

    function notifyChange(force = false) {
        if (
            force ||
            location.href !== lastHref ||
            document.title !== lastTitle
        ) {
            lastHref = location.href;
            lastTitle = document.title;

            // Send update
            window.webkit.messageHandlers.listener.postMessage(
                JSON.stringify({
                    href: lastHref,
                    title: lastTitle,
                    favicon: faviconURL
                })
            );
        }
    }

    // Title mutation observer
    const titleObserver = new MutationObserver(() => notifyChange());
    const titleElement = document.querySelector('title');
    if (titleElement) {
        titleObserver.observe(titleElement, { childList: true });
    }

    // Fallback timer for SPAs
    setInterval(() => notifyChange(), 500);

    // Wrap pushState / replaceState
    const originalPushState = history.pushState;
    history.pushState = function () {
        originalPushState.apply(this, arguments);
        notifyChange(true);
    };

    const originalReplaceState = history.replaceState;
    history.replaceState = function () {
        originalReplaceState.apply(this, arguments);
        notifyChange(true);
    };

    window.addEventListener('popstate', () => notifyChange(true));

    // Fetch favicon once, then trigger first notify
    findFavicon(function (icon) {
        faviconURL = icon;
        notifyChange(true); // Send first message once favicon is known
    });
})();
"""


class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    var onChange: ((String?, URL?) ->Void)?
    weak var tab: Tab?
    private var retryCount = 0
    private let maxRetries = 5
    private let retryDelay: TimeInterval = 1.0
    @EnvironmentObject var historyManager: HistoryManager
    
    override init() {
        super.init()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
        onURLChange?(webView.url)
        onTitleChange?(webView.title)
//        if let title = webView.title, let url = webView.url {
//            onChange?(title, url)
//        }
        
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        onLoadingChange?(false)
        
        onTitleChange?(webView.title)
        onURLChange?(webView.url)

    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)
        onTitleChange?(webView.title)
        onURLChange?(webView.url)
        onChange?(webView.title, webView.url)
        webView.evaluateJavaScript(js, completionHandler: nil)
        // Start the snapshot process after a short delay to allow rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.takeSnapshotAfterLoad(webView)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
  
    
    public func takeSnapshotAfterLoad(_ webView: WKWebView) {
        
//        if retryCount < maxRetries && (webView.isLoading || webView.bounds.width == 0) {
//            print("[Snapshot] Waiting - isLoading: \(webView.isLoading), bounds.width: \(webView.bounds.width), retryCount: \(retryCount)")
//            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
//                print("[Snapshot] Retrying after delay")
//                self?.takeSnapshotAfterLoad(webView)
//            }
//            retryCount += 1
//            return
//        }
        
        guard !webView.isLoading, webView.bounds.width > 0 else {
            retryCount = 0
            return
        }
        
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: 24)
        
        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self = self else {
                return
            }

            if error != nil {
                return
            }

            if let image = image {
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let color = self.extractDominantColor(from: cgImage)
                    DispatchQueue.main.async {
                        if let tab = self.tab {
                            if let color = color {
                                tab.updateBackgroundColor(Color(nsColor: color))
                            } else {
                                tab.updateBackgroundColor( Color(nsColor: NSColor.black))
                            }
                        } else {
                            print("[Snapshot] Tab reference is nil during color set")
                        }
                    }
                } else {
                    print("[Snapshot] Failed to get CGImage from snapshot")
                }
            } else {
                print("[Snapshot] Image is nil")
            }

            self.retryCount = 0
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
