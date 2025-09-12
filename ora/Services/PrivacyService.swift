import Foundation
import WebKit

enum CookiesPolicy: String, CaseIterable, Identifiable, Codable {
    case allowAll = "Allow all"
    case blockThirdParty = "Block third-party"
    case blockAll = "Block all"
    var id: String { rawValue }
}

class PrivacyService {

    private static func clearData(_ container: TabContainer, _ types: Set<String>, _ completion: (() -> Void)?) {
        let dataStore =  WKWebsiteDataStore(forIdentifier: container.id)
        dataStore
            .removeData(
                ofTypes: types,
                modifiedSince: .distantPast
            ) {
                completion?()
            }
    }

    static func clearCookies(_ container: TabContainer, completion: (() -> Void)? = nil) {
        let types: Set<String> = [WKWebsiteDataTypeCookies]
        self.clearData(
            container,
            types,
            completion
        )
    }

    static func clearCache(_ container: TabContainer, completion: (() -> Void)? = nil) {
        let types: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes()
        self.clearData(
            container,
            types,
            completion
        )
    }
}
