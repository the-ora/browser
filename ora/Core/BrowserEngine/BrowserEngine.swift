import Foundation

struct BrowserPageConfiguration {
    let userAgent: String?
    let allowsPictureInPicture: Bool
    let allowsJavaScript: Bool
    let allowsJavaScriptWindowsAutomatically: Bool
    let allowsAirPlayForMediaPlayback: Bool
    let allowsInspectableDebugging: Bool
    let allowsBackForwardNavigationGestures: Bool
    let mediaPlaybackRequiresUserAction: Bool
    let scriptMessageNames: [String]
    let userScripts: [BrowserUserScript]
    let privacySettings: SpacePrivacySettings

    static func oraDefault(
        userScripts: [BrowserUserScript],
        privacySettings: SpacePrivacySettings
    ) -> BrowserPageConfiguration {
        BrowserPageConfiguration(
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0.1 Safari/605.1.15",
            allowsPictureInPicture: true,
            allowsJavaScript: true,
            allowsJavaScriptWindowsAutomatically: false,
            allowsAirPlayForMediaPlayback: true,
            allowsInspectableDebugging: true,
            allowsBackForwardNavigationGestures: true,
            mediaPlaybackRequiresUserAction: false,
            scriptMessageNames: ["listener", "linkHover", "mediaEvent", "passwordManager"],
            userScripts: userScripts,
            privacySettings: privacySettings
        )
    }
}

final class BrowserEngine {
    private struct ProfileKey: Hashable {
        let identifier: UUID
        let isPrivate: Bool
    }

    static let shared = BrowserEngine()
    private let profileCacheLock = NSLock()
    private var profileCache: [ProfileKey: BrowserEngineProfile] = [:]

    func makeProfile(identifier: UUID, isPrivate: Bool) -> BrowserEngineProfile {
        if isPrivate {
            return BrowserEngineProfile(identifier: identifier, isPrivate: true)
        }

        let key = ProfileKey(identifier: identifier, isPrivate: false)
        profileCacheLock.lock()
        defer { profileCacheLock.unlock() }

        if let profile = profileCache[key] {
            return profile
        }

        let profile = BrowserEngineProfile(identifier: identifier, isPrivate: false)
        profileCache[key] = profile
        return profile
    }

    func makePage(
        profile: BrowserEngineProfile,
        configuration: BrowserPageConfiguration,
        delegate: BrowserPageDelegate?
    ) -> BrowserPage {
        BrowserPage(profile: profile, configuration: configuration, delegate: delegate)
    }
}
