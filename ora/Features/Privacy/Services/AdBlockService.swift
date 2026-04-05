import Foundation

actor AdBlockService {
    enum RefreshReason {
        case startup
        case scheduled
        case manual
        case settingsChanged
    }

    static let shared = AdBlockService()

    private let catalogService: FilterListCatalogService
    private let updateService: FilterListUpdateService
    private let compileService: ContentBlockerCompileService
    private let artifactStore: ContentBlockerArtifactStore
    private var knownContainerIDs: Set<UUID> = []
    private var schedulerTask: Task<Void, Never>?

    init(
        catalogService: FilterListCatalogService = .shared,
        updateService: FilterListUpdateService = FilterListUpdateService(),
        compileService: ContentBlockerCompileService = ContentBlockerCompileService(),
        artifactStore: ContentBlockerArtifactStore = .shared
    ) {
        self.catalogService = catalogService
        self.updateService = updateService
        self.compileService = compileService
        self.artifactStore = artifactStore
    }

    func start(containerIDs: [UUID]) async {
        knownContainerIDs.formUnion(containerIDs)
        await MainActor.run {
            SettingsStore.shared.setAdBlockFilterLists(SettingsStore.shared.adBlockFilterLists)
        }

        for containerID in knownContainerIDs where await shouldRefreshOnLaunch(containerId: containerID) {
            _ = await refreshSpace(containerId: containerID, reason: .startup)
        }

        scheduleBackgroundRefresh()
    }

    func registerSpace(containerId: UUID) {
        knownContainerIDs.insert(containerId)
        scheduleBackgroundRefresh()
    }

    func spaceSettingsDidChange(containerId: UUID) {
        knownContainerIDs.insert(containerId)
        scheduleBackgroundRefresh()
    }

    func addCustomList(sourceURL: String, suggestedName: String? = nil) async throws -> FilterListRecord {
        guard let normalizedURL = updateService.normalizedURL(from: sourceURL) else {
            throw AdBlockServiceError.invalidCustomListURL
        }

        let existingRecord = await MainActor.run { () -> FilterListRecord? in
            SettingsStore.shared.adBlockFilterLists.first {
                $0.sourceKind == .custom &&
                    $0.sourceURL.caseInsensitiveCompare(normalizedURL.absoluteString) == .orderedSame
            }
        }

        if let existingRecord {
            return existingRecord
        }

        let defaultName = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = FilterListRecord(
            id: "custom-\(UUID().uuidString.lowercased())",
            name: (defaultName?.isEmpty == false ? defaultName : normalizedURL.host) ?? "Custom Filter List",
            summary: "Custom remotely hosted filter list.",
            sourceKind: .custom,
            sourceURL: normalizedURL.absoluteString,
            isRecommended: false,
            enabledByDefault: false,
            status: .idle
        )

        await MainActor.run {
            SettingsStore.shared.upsertAdBlockFilterList(record)
        }

        _ = await refreshRecord(withID: record.id, allowNetworkFetch: true)

        return await MainActor.run {
            SettingsStore.shared.adBlockFilterList(id: record.id) ?? record
        }
    }

    func renameCustomList(id: String, name: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        await MainActor.run {
            guard var record = SettingsStore.shared.adBlockFilterList(id: id),
                  record.sourceKind == .custom
            else {
                return
            }

            record.name = trimmedName
            SettingsStore.shared.upsertAdBlockFilterList(record)
        }
    }

    func removeCustomList(id: String) async {
        let containerIDs = Array(knownContainerIDs)

        let affectedContainers = await MainActor.run { () -> [UUID] in
            let store = SettingsStore.shared
            store.removeAdBlockFilterList(id: id)
            var affected: [UUID] = []

            for containerID in containerIDs {
                var settings = store.privacySettings(for: containerID)
                guard settings.adBlock.enabledCustomListIDs.contains(id) else { continue }
                settings.adBlock.removeCustomList(id: id)
                store.setPrivacySettings(settings, for: containerID)
                affected.append(containerID)
            }
            return affected
        }

        artifactStore.removeArtifacts(for: id)
        scheduleBackgroundRefresh()

        for containerID in affectedContainers {
            await postPrivacyRefresh(for: containerID)
        }
    }

    @discardableResult
    func refreshSpace(containerId: UUID, reason: RefreshReason) async -> Bool {
        knownContainerIDs.insert(containerId)

        let privacySettings = await MainActor.run {
            SettingsStore.shared.privacySettings(for: containerId)
        }

        guard privacySettings.adBlock.enabled else {
            scheduleBackgroundRefresh()
            if reason == .settingsChanged {
                await postPrivacyRefresh(for: containerId)
            }
            return false
        }

        let enabledListIDs = Set(privacySettings.adBlock.enabledListIDs)
        guard !enabledListIDs.isEmpty else {
            scheduleBackgroundRefresh()
            if reason == .settingsChanged {
                await postPrivacyRefresh(for: containerId)
            }
            return false
        }

        let records = await MainActor.run {
            SettingsStore.shared.adBlockFilterLists
        }

        let selectedRecords = records.filter { enabledListIDs.contains($0.id) }
        var changedListIDs: Set<String> = []

        for record in selectedRecords {
            if await refreshRecord(
                withID: record.id,
                allowNetworkFetch: reason != .settingsChanged || record.activeRevision == nil
            ) {
                changedListIDs.insert(record.id)
            }
        }

        scheduleBackgroundRefresh()

        var containerIDsToRefresh = await affectedContainerIDs(forChangedListIDs: changedListIDs)
        if reason == .settingsChanged {
            containerIDsToRefresh.insert(containerId)
        }

        for affectedContainerID in containerIDsToRefresh {
            await postPrivacyRefresh(for: affectedContainerID)
        }

        return !changedListIDs.isEmpty
    }

    static func failedRecord(_ record: FilterListRecord, error: Error) -> FilterListRecord {
        var failed = record
        failed.status = .failed
        failed.lastErrorMessage = error.localizedDescription
        return failed
    }

    private func refreshRecord(withID recordID: String, allowNetworkFetch: Bool) async -> Bool {
        guard let record = await MainActor.run(body: {
            SettingsStore.shared.adBlockFilterList(id: recordID)
        }) else {
            return false
        }

        await updateRecord(record) { draft in
            draft.status = .updating
            draft.lastErrorMessage = nil
        }

        do {
            let fetchResult = try await resolveFilterSource(for: record, allowNetworkFetch: allowNetworkFetch)
            let rawText = try rawText(for: fetchResult.record, fetchedRawText: fetchResult.rawText)
            let revision = artifactStore.revisionHash(for: rawText)
            let hadActiveRevision = record.activeRevision

            let coverage: FilterListCoverage
            if artifactStore.hasCompiledArtifacts(for: record.id, revision: revision),
               let cachedCoverage = artifactStore.coverage(for: record.id, revision: revision)
            {
                coverage = cachedCoverage
            } else {
                let compiled = try compileService.compile(record: fetchResult.record, rawText: rawText)
                try artifactStore.storeRawListText(rawText, for: record.id)
                try artifactStore.storeCompiledArtifacts(
                    jsonShards: compiled.jsonShards,
                    coverage: compiled.coverage,
                    for: record.id,
                    revision: compiled.revision
                )
                coverage = compiled.coverage
            }

            await MainActor.run {
                var updatedRecord = fetchResult.record
                updatedRecord.status = .ready
                updatedRecord.lastErrorMessage = nil
                updatedRecord.coverage = coverage
                updatedRecord.activeRevision = revision
                updatedRecord.lastSuccessfulRefreshAt = Date()
                SettingsStore.shared.upsertAdBlockFilterList(updatedRecord)
            }

            return hadActiveRevision != revision
        } catch {
            await MainActor.run {
                if let current = SettingsStore.shared.adBlockFilterList(id: record.id) {
                    SettingsStore.shared.upsertAdBlockFilterList(Self.failedRecord(current, error: error))
                }
            }
            return false
        }
    }

    private func resolveFilterSource(
        for record: FilterListRecord,
        allowNetworkFetch: Bool
    ) async throws -> FilterListFetchResult {
        guard allowNetworkFetch || artifactStore.rawListText(for: record.id) != nil else {
            throw AdBlockServiceError.missingCachedList(record.name)
        }

        if allowNetworkFetch {
            do {
                return try await updateService.fetchLatest(for: record)
            } catch {
                guard artifactStore.rawListText(for: record.id) != nil else { throw error }
                var fallbackRecord = record
                fallbackRecord.lastErrorMessage = error.localizedDescription
                return FilterListFetchResult(record: fallbackRecord, rawText: nil)
            }
        }

        return FilterListFetchResult(record: record, rawText: nil)
    }

    private func rawText(for record: FilterListRecord, fetchedRawText: String?) throws -> String {
        if let fetchedRawText {
            return fetchedRawText
        }
        if let cached = artifactStore.rawListText(for: record.id) {
            return cached
        }
        throw AdBlockServiceError.missingCachedList(record.name)
    }

    private func affectedContainerIDs(forChangedListIDs changedListIDs: Set<String>) async -> Set<UUID> {
        guard !changedListIDs.isEmpty else { return [] }
        let containerIDs = Array(knownContainerIDs)

        return await MainActor.run {
            let store = SettingsStore.shared

            return Set(containerIDs.filter { containerID in
                let settings = store.privacySettings(for: containerID)
                guard settings.adBlock.enabled else { return false }
                return !changedListIDs.isDisjoint(with: settings.adBlock.enabledListIDs)
            })
        }
    }

    private func shouldRefreshOnLaunch(containerId: UUID) async -> Bool {
        await MainActor.run {
            let store = SettingsStore.shared
            let settings = store.privacySettings(for: containerId)
            guard settings.adBlock.enabled,
                  settings.adBlock.updateMode != .manualOnly
            else {
                return false
            }

            let enabledRecords = store.adBlockFilterLists.filter {
                settings.adBlock.enabledListIDs.contains($0.id)
            }

            guard !enabledRecords.isEmpty else { return false }

            let cutoff = Date().addingTimeInterval(-(settings.adBlock.updateMode.refreshInterval ?? 0))
            return enabledRecords.contains {
                $0.activeRevision == nil || ($0.lastSuccessfulRefreshAt ?? .distantPast) < cutoff
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        schedulerTask?.cancel()

        schedulerTask = Task { [weak self] in
            guard let self else { return }
            guard let nextWakeInterval = await self.minimumAutoRefreshInterval() else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(nextWakeInterval))
                guard !Task.isCancelled else { break }
                await self.refreshScheduledSpaces()
            }
        }
    }

    private func minimumAutoRefreshInterval() async -> TimeInterval? {
        let containerIDs = Array(knownContainerIDs)
        return await MainActor.run {
            let store = SettingsStore.shared

            return containerIDs.compactMap { containerID -> TimeInterval? in
                let settings = store.privacySettings(for: containerID)
                guard settings.adBlock.enabled else { return nil }
                return settings.adBlock.updateMode.refreshInterval
            }.min()
        }
    }

    private func refreshScheduledSpaces() async {
        let knownIDs = Array(knownContainerIDs)
        let containerIDs = await MainActor.run { () -> [UUID] in
            let store = SettingsStore.shared
            return knownIDs.filter { containerID in
                let settings = store.privacySettings(for: containerID)
                guard settings.adBlock.enabled,
                      let refreshInterval = settings.adBlock.updateMode.refreshInterval
                else {
                    return false
                }

                let enabledRecords = store.adBlockFilterLists.filter {
                    settings.adBlock.enabledListIDs.contains($0.id)
                }

                guard !enabledRecords.isEmpty else { return false }

                let cutoff = Date().addingTimeInterval(-refreshInterval)
                return enabledRecords.contains {
                    $0.activeRevision == nil || ($0.lastSuccessfulRefreshAt ?? .distantPast) < cutoff
                }
            }
        }

        for containerID in containerIDs {
            _ = await refreshSpace(containerId: containerID, reason: .scheduled)
        }
    }

    private func updateRecord(_ record: FilterListRecord, mutate: @escaping (inout FilterListRecord) -> Void) async {
        await MainActor.run {
            guard var storedRecord = SettingsStore.shared.adBlockFilterList(id: record.id) else { return }
            mutate(&storedRecord)
            SettingsStore.shared.upsertAdBlockFilterList(storedRecord)
        }
    }

    private func postPrivacyRefresh(for containerId: UUID) async {
        await MainActor.run {
            SettingsStore.shared.notifySpacePrivacySettingsChanged(for: containerId)
        }
    }
}
