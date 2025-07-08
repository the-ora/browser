import WebKit
import AppKit

// MARK: - WebView Navigation Delegate
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChange: ((String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    var onThemeColorExtracted: ((NSColor?) -> Void)? 
    
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

        // 🌈 Extract theme color from <meta name="theme-color">
        webView.evaluateJavaScript("""
        (function() {
            var meta = document.querySelector('meta[name="theme-color"]');
            return meta ? meta.content : null;
        })()
        """) { result, _ in
            if let hex = result as? String,
               let nsColor = NSColor(hex: hex) {
                self.onThemeColorExtracted?(nsColor)
            }
        }

        // 🌇 Fallback: extract computed body background color
        webView.evaluateJavaScript("""
            window.getComputedStyle(document.body).backgroundColor;
        """) { result, _ in
            if let cssColor = result as? String,
                let nsColor = NSColor.fromCSSColorString(cssColor) {
                self.onThemeColorExtracted?(nsColor)
            }
        }

        // 🖼️ Fetch favicon and extract color as fallback
        if let host = webView.url?.host,
           let faviconURL = URL(string: "https://\(host)/favicon.ico") {
            URLSession.shared.dataTask(with: faviconURL) { data, _, _ in
                if let data = data, let image = NSImage(data: data),
                   let dominantColor = image.dominantColor() {
                    self.onThemeColorExtracted?(dominantColor)
                }
            }.resume()
        }
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
    }
} 

extension NSImage {
    func dominantColor() -> NSColor? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0

        for x in 0..<width {
            for y in 0..<height {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                
                // Ignore nearly white or black pixels
                let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                if brightness > 0.95 || brightness < 0.05 { continue }
                
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }

        guard count > 0 else { return nil }

        return NSColor(
            red: red / count,
            green: green / count,
            blue: blue / count,
            alpha: 1.0
        )
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xff) / 255
        let g = CGFloat((rgb >> 8) & 0xff) / 255
        let b = CGFloat(rgb & 0xff) / 255

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension NSColor {
    static func fromCSSColorString(_ cssString: String) -> NSColor? {
        let pattern = #"rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cssString, range: NSRange(cssString.startIndex..., in: cssString)) else {
            return nil
        }
        
        let nsStr = cssString as NSString
        let r = CGFloat(Int(nsStr.substring(with: match.range(at: 1))) ?? 0) / 255.0
        let g = CGFloat(Int(nsStr.substring(with: match.range(at: 2))) ?? 0) / 255.0
        let b = CGFloat(Int(nsStr.substring(with: match.range(at: 3))) ?? 0) / 255.0
        let a = match.range(at: 4).location != NSNotFound ? CGFloat(Double(nsStr.substring(with: match.range(at: 4))) ?? 1.0) : 1.0
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
}