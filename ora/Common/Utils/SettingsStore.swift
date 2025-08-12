import Foundation
import SwiftUI

struct SitePermissionSettings: Codable, Hashable, Identifiable {
    var id: String { host }
    let host: String
    var camera: Bool
    var microphone: Bool
    var location: Bool
    var notifications: Bool
}

enum AutoClearTabsAfter: String, CaseIterable, Identifiable, Codable {
    case never = "Never"
    case oneHour = "1 Hour"
    case oneDay = "1 Day"
    case oneWeek = "1 Week"
    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .never: return nil
        case .oneHour: return 3600
        case .oneDay: return 86400
        case .oneWeek: return 604_800
        }
    }
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    // MARK: - Global keys

    private let autoUpdateKey = "settings.autoUpdateEnabled"
    private let trackingThirdPartyKey = "settings.tracking.blockThirdParty"
    private let fingerprintingKey = "settings.tracking.blockFingerprinting"
    private let adBlockingKey = "settings.tracking.adBlocking"
    private let cookiesPolicyKey = "settings.cookies.policy"
    private let sitePermissionsKey = "settings.permissions.sitePermissions"

    // MARK: - Per-Container

    private func keyForDefaultSearch(for containerId: UUID) -> String {
        "settings.container.\(containerId.uuidString).defaultSearch"
    }

    private func keyForDefaultAI(for containerId: UUID) -> String {
        "settings.container.\(containerId.uuidString).defaultAI"
    }

    private func keyForAutoClear(for containerId: UUID) -> String {
        "settings.container.\(containerId.uuidString).autoClearTabsAfter"
    }

    @Published var autoUpdateEnabled: Bool {
        didSet { defaults.set(autoUpdateEnabled, forKey: autoUpdateKey) }
    }

    @Published var blockThirdPartyTrackers: Bool {
        didSet { defaults.set(blockThirdPartyTrackers, forKey: trackingThirdPartyKey) }
    }

    @Published var blockFingerprinting: Bool {
        didSet { defaults.set(blockFingerprinting, forKey: fingerprintingKey) }
    }

    @Published var adBlocking: Bool {
        didSet { defaults.set(adBlocking, forKey: adBlockingKey) }
    }

    @Published var cookiesPolicy: CookiesPolicy {
        didSet { defaults.set(cookiesPolicy.rawValue, forKey: cookiesPolicyKey) }
    }

    @Published var sitePermissions: [String: SitePermissionSettings] {
        didSet { saveCodable(sitePermissions, forKey: sitePermissionsKey) }
    }

    init() {
        autoUpdateEnabled = defaults.bool(forKey: autoUpdateKey)
        blockThirdPartyTrackers = defaults.bool(forKey: trackingThirdPartyKey)
        blockFingerprinting = defaults.bool(forKey: fingerprintingKey)
        adBlocking = defaults.bool(forKey: adBlockingKey)
        if let raw = defaults.string(forKey: cookiesPolicyKey),
           let policy = CookiesPolicy(rawValue: raw)
        {
            cookiesPolicy = policy
        } else {
            cookiesPolicy = .allowAll
        }

        sitePermissions =
            Self.loadCodable([String: SitePermissionSettings].self, key: sitePermissionsKey) ?? [:]
    }

    // MARK: - Per-container helpers

    func defaultSearchEngineId(for containerId: UUID) -> String? {
        defaults.string(forKey: keyForDefaultSearch(for: containerId))
    }

    func setDefaultSearchEngineId(_ id: String?, for containerId: UUID) {
        defaults.set(id, forKey: keyForDefaultSearch(for: containerId))
        objectWillChange.send()
    }

    func defaultAIEngineId(for containerId: UUID) -> String? {
        defaults.string(forKey: keyForDefaultAI(for: containerId))
    }

    func setDefaultAIEngineId(_ id: String?, for containerId: UUID) {
        defaults.set(id, forKey: keyForDefaultAI(for: containerId))
        objectWillChange.send()
    }

    func autoClearTabsAfter(for containerId: UUID) -> AutoClearTabsAfter {
        if let raw = defaults.string(forKey: keyForAutoClear(for: containerId)),
           let value = AutoClearTabsAfter(rawValue: raw)
        {
            return value
        }
        return .never
    }

    func setAutoClearTabsAfter(_ value: AutoClearTabsAfter, for containerId: UUID) {
        defaults.set(value.rawValue, forKey: keyForAutoClear(for: containerId))
        objectWillChange.send()
    }

    // MARK: - Permissions

    func upsertSitePermission(_ permission: SitePermissionSettings) {
        var copy = sitePermissions
        copy[permission.host] = permission
        sitePermissions = copy
    }

    func removeSitePermission(host: String) {
        var copy = sitePermissions
        copy.removeValue(forKey: host)
        sitePermissions = copy
    }

    // MARK: - Codable helpers

    private func saveCodable(_ value: some Encodable, forKey key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
