import Foundation
import WebKit

enum CookiesPolicy: String, CaseIterable, Identifiable, Codable {
    case allowAll = "Allow all"
    case blockThirdParty = "Block third-party"
    case blockAll = "Block all"
    var id: String { rawValue }
}

class PrivacyService {
    static func clearCookies(completion: (() -> Void)? = nil) {
        let types: Set<String> = [WKWebsiteDataTypeCookies]
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) {
            completion?()
        }
    }

    static func clearCache(completion: (() -> Void)? = nil) {
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) {
            completion?()
        }
    }

    static func clearAllWebsiteData(completion: (() -> Void)? = nil) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        ) {
            completion?()
        }
    }
}
