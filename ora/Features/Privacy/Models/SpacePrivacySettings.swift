import Foundation

struct SpacePrivacySettings: Codable, Equatable, Hashable {
    var blockThirdPartyTrackers: Bool
    var blockFingerprinting: Bool
    var adBlock: SpaceAdBlockSettings
    var cookiesPolicy: CookiesPolicy

    init(
        blockThirdPartyTrackers: Bool = false,
        blockFingerprinting: Bool = true,
        adBlocking: Bool = false,
        adBlock: SpaceAdBlockSettings? = nil,
        cookiesPolicy: CookiesPolicy = .allowAll
    ) {
        self.blockThirdPartyTrackers = blockThirdPartyTrackers
        self.blockFingerprinting = blockFingerprinting
        self.adBlock = adBlock ?? SpaceAdBlockSettings(enabled: adBlocking)
        self.cookiesPolicy = cookiesPolicy
    }

    var adBlocking: Bool {
        get { adBlock.enabled }
        set { adBlock.enabled = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case blockThirdPartyTrackers
        case blockFingerprinting
        case adBlocking
        case adBlock
        case cookiesPolicy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockThirdPartyTrackers = try container.decodeIfPresent(Bool.self, forKey: .blockThirdPartyTrackers) ?? false
        blockFingerprinting = try container.decodeIfPresent(Bool.self, forKey: .blockFingerprinting) ?? true
        cookiesPolicy = try container.decodeIfPresent(CookiesPolicy.self, forKey: .cookiesPolicy) ?? .allowAll

        if let nestedAdBlock = try container.decodeIfPresent(SpaceAdBlockSettings.self, forKey: .adBlock) {
            adBlock = nestedAdBlock
        } else {
            let legacyAdBlocking = try container.decodeIfPresent(Bool.self, forKey: .adBlocking) ?? false
            adBlock = SpaceAdBlockSettings(enabled: legacyAdBlocking)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockThirdPartyTrackers, forKey: .blockThirdPartyTrackers)
        try container.encode(blockFingerprinting, forKey: .blockFingerprinting)
        try container.encode(adBlock, forKey: .adBlock)
        try container.encode(cookiesPolicy, forKey: .cookiesPolicy)
    }
}
