import AppKit
import SwiftUI

class FaviconService: ObservableObject {
    private var cache: [String: NSImage] = [:]

    func getFavicon(for searchURL: String) -> NSImage? {
        guard let domain = extractDomain(from: searchURL) else { return nil }

        if let cachedFavicon = cache[domain] {
            return cachedFavicon
        }

        // Try to fetch favicon asynchronously
        fetchFavicon(for: domain) { [weak self] favicon in
            if let favicon {
                DispatchQueue.main.async {
                    self?.cache[domain] = favicon
                    self?.objectWillChange.send()
                }
            }
        }

        return nil
    }

    private func extractDomain(from searchURL: String) -> String? {
        guard let url = URL(string: searchURL) else { return nil }
        return url.host
    }

    private func fetchFavicon(for domain: String, completion: @escaping (NSImage?) -> Void) {
        let faviconURLs = [
            "https://\(domain)/favicon.ico",
            "https://\(domain)/apple-touch-icon.png",
            "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"
        ]

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
}

extension NSImage {
    var isValid: Bool {
        return representations.count > 0
    }
}
