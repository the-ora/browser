import Foundation

enum CookiesPolicy: String, CaseIterable, Identifiable, Codable {
    case allowAll = "Allow all"
    case blockThirdParty = "Block third-party"
    case blockAll = "Block all"
    var id: String {
        rawValue
    }
}

class PrivacyService {
    private static func profile(for container: TabContainer) -> BrowserEngineProfile {
        BrowserEngines.shared.current.makeProfile(identifier: container.id, isPrivate: false)
    }

    private static func clearData(
        _ container: TabContainer,
        _ types: Set<BrowserWebsiteDataType>,
        host: String? = nil,
        _ completion: (() -> Void)?
    ) {
        profile(for: container).clearData(ofTypes: types, forHost: host, completion: completion)
    }

    static func clearCookies(_ container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(
            container,
            [.cookies],
            completion
        )
    }

    static func clearCache(_ container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(
            container,
            [.all],
            completion
        )
    }

    static func clearCookiesForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(container, [.cookies], host: host, completion)
    }

    static func clearCacheForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(container, [.all], host: host, completion)
    }
}
