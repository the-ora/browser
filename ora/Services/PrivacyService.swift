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

    static func clearCookiesForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore(forIdentifier: container.id)
        let types: Set<String> = [WKWebsiteDataTypeCookies]
        dataStore.fetchDataRecords(ofTypes: types) { records in
            let targetRecords = records.filter { $0.displayName.contains(host) }
            guard !targetRecords.isEmpty else {
                completion?()
                return
            }

            dataStore.removeData(ofTypes: types, for: targetRecords) {
                completion?()
            }
        }
    }

    static func clearCacheForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore(forIdentifier: container.id)
        let types: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: types) { records in
            let targetRecords = records.filter { $0.displayName.contains(host) }
            guard !targetRecords.isEmpty else {
                completion?()
                return
            }

            dataStore.removeData(ofTypes: types, for: targetRecords) {
                completion?()
            }
        }
    }
}
