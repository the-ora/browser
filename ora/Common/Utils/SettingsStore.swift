import AppKit
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

struct CustomSearchEngine: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let searchURL: String
    let aliases: [String]
    let faviconData: Data?
    let faviconBackgroundColorData: Data?
    let isAIChat: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        searchURL: String,
        aliases: [String] = [],
        faviconData: Data? = nil,
        faviconBackgroundColorData: Data? = nil,
        isAIChat: Bool = false
    ) {
        self.id = id
        self.name = name
        self.searchURL = searchURL
        self.aliases = aliases
        self.faviconData = faviconData
        self.faviconBackgroundColorData = faviconBackgroundColorData
        self.isAIChat = isAIChat
    }

    var favicon: NSImage? {
        guard let data = faviconData else { return nil }
        return NSImage(data: data)
    }

    var faviconBackgroundColor: Color? {
        guard let data = faviconBackgroundColorData else { return nil }
        do {
            let nsColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            return nsColor.map(Color.init)
        } catch {
            return nil
        }
    }

    static func createWithFavicon(
        id: String = UUID().uuidString,
        name: String,
        searchURL: String,
        aliases: [String] = [],
        isAIChat: Bool = false,
        completion: @escaping (CustomSearchEngine) -> Void
    ) {
        let faviconService = FaviconService.shared

        // Try to fetch favicon synchronously first (from cache)
        if let favicon = faviconService.getFavicon(for: searchURL) {
            let faviconData = favicon.tiffRepresentation
            let backgroundColor = Color(favicon.averageColor())
            let colorData = try? NSKeyedArchiver.archivedData(
                withRootObject: NSColor(backgroundColor),
                requiringSecureCoding: false
            )

            let engine = CustomSearchEngine(
                id: id,
                name: name,
                searchURL: searchURL,
                aliases: aliases,
                faviconData: faviconData,
                faviconBackgroundColorData: colorData,
                isAIChat: isAIChat
            )
            completion(engine)
        } else {
            // Fetch async and update
            faviconService.fetchFaviconSync(for: searchURL) { favicon in
                DispatchQueue.main.async {
                    var faviconData: Data?
                    var colorData: Data?

                    if let favicon {
                        faviconData = favicon.tiffRepresentation
                        let backgroundColor = Color(favicon.averageColor())
                        colorData = try? NSKeyedArchiver.archivedData(
                            withRootObject: NSColor(backgroundColor),
                            requiringSecureCoding: false
                        )
                    }

                    let engine = CustomSearchEngine(
                        id: id,
                        name: name,
                        searchURL: searchURL,
                        aliases: aliases,
                        faviconData: faviconData,
                        faviconBackgroundColorData: colorData,
                        isAIChat: isAIChat
                    )
                    completion(engine)
                }
            }
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
    private let customSearchEnginesKey = "settings.customSearchEngines"
    private let globalDefaultSearchEngineKey = "settings.globalDefaultSearchEngine"
    private let customKeyboardShortcutsKey = "settings.customKeyboardShortcuts"
    private let tabAliveTimeoutKey = "settings.tabAliveTimeout"
    private let tabRemovalTimeoutKey = "settings.tabRemovalTimeout"
    private let maxRecentTabsKey = "settings.maxRecentTabs"
    private let autoPiPEnabledKey = "settings.autoPiPEnabled"
    private let themePrimaryColorKey = "settings.theme.primaryColor"
    private let themeAccentColorKey = "settings.theme.accentColor"

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

    @Published var customSearchEngines: [CustomSearchEngine] {
        didSet { saveCodable(customSearchEngines, forKey: customSearchEnginesKey) }
    }

    @Published var globalDefaultSearchEngine: String? {
        didSet { defaults.set(globalDefaultSearchEngine, forKey: globalDefaultSearchEngineKey) }
    }

    @Published var customKeyboardShortcuts: [String: KeyChord] {
        didSet { saveCodable(customKeyboardShortcuts, forKey: customKeyboardShortcutsKey) }
    }

    @Published var tabAliveTimeout: TimeInterval {
        didSet { defaults.set(tabAliveTimeout, forKey: tabAliveTimeoutKey) }
    }

    @Published var tabRemovalTimeout: TimeInterval {
        didSet { defaults.set(tabRemovalTimeout, forKey: tabRemovalTimeoutKey) }
    }

    @Published var maxRecentTabs: Int {
        didSet { defaults.set(maxRecentTabs, forKey: maxRecentTabsKey) }
    }

    @Published var autoPiPEnabled: Bool {
        didSet { defaults.set(autoPiPEnabled, forKey: autoPiPEnabledKey) }
    }

    @Published var themePrimaryColor: String? {
        didSet { defaults.set(themePrimaryColor, forKey: themePrimaryColorKey) }
    }

    @Published var themeAccentColor: String? {
        didSet { defaults.set(themeAccentColor, forKey: themeAccentColorKey) }
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

        customSearchEngines =
            Self.loadCodable([CustomSearchEngine].self, key: customSearchEnginesKey) ?? []

        globalDefaultSearchEngine = defaults.string(forKey: globalDefaultSearchEngineKey)

        customKeyboardShortcuts =
            Self.loadCodable([String: KeyChord].self, key: customKeyboardShortcutsKey) ?? [:]

        let aliveTimeoutValue = defaults.double(forKey: tabAliveTimeoutKey)
        let supportedTimeouts: [TimeInterval] = [
            60 * 60,           // 1 hour
            6 * 60 * 60,       // 6 hours
            12 * 60 * 60,      // 12 hours
            24 * 60 * 60,      // 1 day
            2 * 24 * 60 * 60,  // 2 days
            365 * 24 * 60 * 60 // "Never" sentinel
        ]
        let normalizedAlive = Self.normalizeTimeout(
            aliveTimeoutValue,
            defaultSeconds: 60 * 60,
            supported: supportedTimeouts
        )
        defaults.set(normalizedAlive, forKey: tabAliveTimeoutKey)
        tabAliveTimeout = normalizedAlive

        let removalTimeoutValue = defaults.double(forKey: tabRemovalTimeoutKey)
        let normalizedRemoval = Self.normalizeTimeout(
            removalTimeoutValue,
            defaultSeconds: 24 * 60 * 60,
            supported: supportedTimeouts
        )
        defaults.set(normalizedRemoval, forKey: tabRemovalTimeoutKey)
        tabRemovalTimeout = normalizedRemoval

        let maxRecentTabsValue = defaults.integer(forKey: maxRecentTabsKey)
        maxRecentTabs = maxRecentTabsValue == 0 ? 5 : maxRecentTabsValue

        autoPiPEnabled = defaults.object(forKey: autoPiPEnabledKey) as? Bool ?? true

        themePrimaryColor = defaults.string(forKey: themePrimaryColorKey)
        themeAccentColor = defaults.string(forKey: themeAccentColorKey)
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

    // MARK: - Custom Search Engines

    func addCustomSearchEngine(_ engine: CustomSearchEngine) {
        var engines = customSearchEngines
        engines.append(engine)
        customSearchEngines = engines
    }

    func removeCustomSearchEngine(withId id: String) {
        customSearchEngines = customSearchEngines.filter { $0.id != id }
    }

    func updateCustomSearchEngine(_ engine: CustomSearchEngine) {
        var engines = customSearchEngines
        if let index = engines.firstIndex(where: { $0.id == engine.id }) {
            engines[index] = engine
            customSearchEngines = engines
        }
    }

    // MARK: - Custom Keyboard Shortcuts

    func setCustomKeyboardShortcut(id: String, keyChord: KeyChord) {
        var shortcuts = customKeyboardShortcuts
        shortcuts[id] = keyChord
        customKeyboardShortcuts = shortcuts
    }

    func removeCustomKeyboardShortcut(id: String) {
        var shortcuts = customKeyboardShortcuts
        shortcuts.removeValue(forKey: id)
        customKeyboardShortcuts = shortcuts
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

    // MARK: - Normalization helpers

    private static func normalizeTimeout(
        _ raw: TimeInterval,
        defaultSeconds: TimeInterval,
        supported: [TimeInterval]
    ) -> TimeInterval {
        let value: TimeInterval = raw == 0 ? defaultSeconds : raw

        if supported.contains(value) {
            return value
        }

        return supported.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? defaultSeconds
    }
}
