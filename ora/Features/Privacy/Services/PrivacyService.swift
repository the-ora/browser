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
    @MainActor static func clearAllWebsiteData(for containerId: UUID) async {
        await withCheckedContinuation { continuation in
            BrowserEngine.shared
                .makeProfile(identifier: containerId, isPrivate: false)
                .clearData(ofTypes: [.all]) {
                    continuation.resume()
                }
        }
    }

    private static func profile(for container: TabContainer) -> BrowserEngineProfile {
        BrowserEngine.shared.makeProfile(identifier: container.id, isPrivate: false)
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
            [.cache],
            completion
        )
    }

    static func clearCookiesForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(container, [.cookies], host: host, completion)
    }

    static func clearCacheForHost(for host: String, container: TabContainer, completion: (() -> Void)? = nil) {
        self.clearData(container, [.cache], host: host, completion)
    }
}
