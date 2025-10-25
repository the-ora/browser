import AppKit
import CoreImage
import SwiftUI

class FaviconService: ObservableObject {
    static let shared = FaviconService()
    private var cache: [String: NSImage] = [:]
    private var colorCache: [String: Color] = [:]

    func getFavicon(for searchURL: String) -> NSImage? {
        guard let domain = extractDomain(from: searchURL) else { return nil }
        // Try to fetch favicon asynchronously
        fetchFavicon(for: domain) { [weak self] favicon in
            if let favicon {
                DispatchQueue.main.async {
                    self?.cache[domain] = favicon
                    self?.colorCache[domain] = Color(favicon.averageColor())
                    self?.objectWillChange.send()
                }
            }
        }

        if let cachedFavicon = cache[domain] {
            return cachedFavicon
        }

        return nil
    }

    func getFaviconColor(for searchURL: String) -> Color? {
        guard let domain = extractDomain(from: searchURL) else { return nil }

        if let cachedColor = colorCache[domain] {
            return cachedColor
        }

        // If favicon exists but color doesn't, compute it
        if let favicon = cache[domain] {
            let color = Color(favicon.averageColor())
            colorCache[domain] = color
            return color
        }

        // Trigger favicon fetch which will also compute color
        _ = getFavicon(for: searchURL)
        return nil
    }

    func faviconURL(for domain: String) -> URL? {
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
    }

    private func extractDomain(from searchURL: String) -> String? {
        guard let url = URL(string: searchURL) else { return nil }
        return url.host
    }

    func fetchFaviconSync(for searchURL: String, completion: @escaping (NSImage?) -> Void) {
        guard let domain = extractDomain(from: searchURL) else {
            completion(nil)
            return
        }
        fetchFavicon(for: domain, completion: completion)
    }

    private func fetchFavicon(for domain: String, completion: @escaping (NSImage?) -> Void) {
        let faviconURLs = self.getFaviconURLs(for: domain)
        tryFetchingFavicon(from: faviconURLs, index: 0, completion: completion)
    }

    private func tryFetchingFavicon(from urls: [String], index: Int, completion: @escaping (NSImage?) -> Void) {
        guard index < urls.count else {
            completion(nil)
            return
        }

        guard let url = URL(string: urls[index]) else {
            tryFetchingFavicon(from: urls, index: index + 1, completion: completion)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let image = NSImage(data: data), image.isValid {
                completion(image)
            } else {
                self.tryFetchingFavicon(from: urls, index: index + 1, completion: completion)
            }
        }.resume()
    }

    private func getFaviconURLs(for domain: String) -> [String] {
        let faviconURLs = [
            "https://www.google.com/s2/favicons?domain=\(domain)&sz=64",
            "https://\(domain)/apple-touch-icon.png",
            "https://\(domain)/favicon.ico"
        ]
        return faviconURLs
    }

    private func tryFetchingFaviconData(from urls: [String], index: Int, completion: @escaping (Data?, URL?) -> Void) {
        guard index < urls.count else {
            completion(nil, nil)
            return
        }
        guard let url = URL(string: urls[index]) else {
            tryFetchingFaviconData(from: urls, index: index + 1, completion: completion)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data {
                completion(data, url)
            } else {
                self.tryFetchingFaviconData(from: urls, index: index + 1, completion: completion)
            }
        }.resume()
    }

    func downloadAndSaveFavicon(
        for domain: String,
        faviconURL: URL,
        to saveURL: URL,
        completion: @escaping (URL?, Bool) -> Void
    ) {
        var faviconURLs = self.getFaviconURLs(for: domain)
        faviconURLs.insert(faviconURL.absoluteString, at: 0)
        tryFetchingFaviconData(from: faviconURLs, index: 0) { data, url in
            if let data, let url {
                do {
                    try data.write(to: saveURL, options: .atomic)
                    completion(url, true)
                } catch {
                    completion(nil, false)
                }
            } else {
                completion(nil, false)
            }
        }
    }
}

extension NSImage {
    var isValid: Bool {
        return !representations.isEmpty
    }

    func averageColor() -> NSColor {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return NSColor.gray
        }

        let inputImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]
        ) else {
            return NSColor.gray
        }

        guard let outputImage = filter.outputImage else {
            return NSColor.gray
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return NSColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255
        )
    }
}
