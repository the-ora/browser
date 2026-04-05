import Foundation

struct FilterListCatalogService {
    static let shared = FilterListCatalogService()

    static let adGuardBaseID = "adguard-base"
    static let adGuardMobileAdsID = "adguard-mobile-ads"
    static let adGuardTrackingProtectionID = "adguard-tracking-protection"
    static let adGuardURLTrackingID = "adguard-url-tracking"
    static let adGuardAnnoyancesID = "adguard-annoyances"

    static let defaultBuiltinSelectionIDs = [
        adGuardBaseID,
        adGuardMobileAdsID
    ]

    let builtinRecords: [FilterListRecord] = [
        FilterListRecord(
            id: FilterListCatalogService.adGuardBaseID,
            name: "AdGuard Base",
            summary: "Core AdGuard ads list for general web ad blocking.",
            sourceKind: .builtin,
            sourceURL: "https://filters.adtidy.org/extension/chromium/filters/2.txt",
            isRecommended: true,
            enabledByDefault: true,
            status: .idle
        ),
        FilterListRecord(
            id: FilterListCatalogService.adGuardMobileAdsID,
            name: "AdGuard Mobile Ads",
            summary: "Additional mobile ad-network coverage for embedded and responsive mobile ads.",
            sourceKind: .builtin,
            sourceURL: "https://filters.adtidy.org/extension/chromium/filters/11.txt",
            isRecommended: true,
            enabledByDefault: true,
            status: .idle
        ),
        FilterListRecord(
            id: FilterListCatalogService.adGuardTrackingProtectionID,
            name: "AdGuard Tracking Protection",
            summary: "Broader tracker and analytics coverage from AdGuard’s privacy list.",
            sourceKind: .builtin,
            sourceURL: "https://filters.adtidy.org/extension/chromium/filters/3.txt",
            isRecommended: false,
            enabledByDefault: false,
            status: .idle
        ),
        FilterListRecord(
            id: FilterListCatalogService.adGuardURLTrackingID,
            name: "AdGuard URL Tracking",
            summary: "Removes common tracking parameters from requested URLs when WebKit rules can express them.",
            sourceKind: .builtin,
            sourceURL: "https://filters.adtidy.org/windows/filters/17.txt",
            isRecommended: false,
            enabledByDefault: false,
            status: .idle
        ),
        FilterListRecord(
            id: FilterListCatalogService.adGuardAnnoyancesID,
            name: "AdGuard Annoyances",
            summary: "Targets cookie notices, popups, widgets, and other page annoyances.",
            sourceKind: .builtin,
            sourceURL: "https://filters.adtidy.org/extension/chromium/filters/14.txt",
            isRecommended: false,
            enabledByDefault: false,
            status: .idle
        )
    ]

    func normalizedRecords(from stored: [FilterListRecord]) -> [FilterListRecord] {
        let builtinByID = Dictionary(uniqueKeysWithValues: builtinRecords.map { ($0.id, $0) })
        let storedByID = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })

        let mergedBuiltins = builtinRecords.map { builtin -> FilterListRecord in
            guard let storedBuiltin = storedByID[builtin.id] else { return builtin }

            var merged = builtin
            merged.status = storedBuiltin.status
            merged.lastErrorMessage = storedBuiltin.lastErrorMessage
            merged.lastFetchAt = storedBuiltin.lastFetchAt
            merged.lastSuccessfulRefreshAt = storedBuiltin.lastSuccessfulRefreshAt
            merged.etag = storedBuiltin.etag
            merged.lastModified = storedBuiltin.lastModified
            merged.activeRevision = storedBuiltin.activeRevision
            merged.coverage = storedBuiltin.coverage
            return merged
        }

        let customRecords = stored
            .filter { $0.sourceKind == .custom && builtinByID[$0.id] == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return mergedBuiltins + customRecords
    }
}
