import Foundation
import SwiftData

enum PermissionKind: CaseIterable {
    case camera, microphone
}

@MainActor
final class PermissionSettingsStore: ObservableObject {
    // Use an explicitly initialized shared instance from App setup
    static var shared: PermissionSettingsStore!

    @Published private(set) var sitePermissions: [SitePermission]

    private let context: ModelContext

    // Safer init: no AppDelegate poking here
    init(context: ModelContext) {
        self.context = context
        self.sitePermissions = (try? context.fetch(
            FetchDescriptor<SitePermission>(sortBy: [.init(\.host)])
        )) ?? []
    }

    // Refresh permissions from context
    func refreshPermissions() {
        self.sitePermissions = (try? context.fetch(
            FetchDescriptor<SitePermission>(sortBy: [.init(\.host)])
        )) ?? []
        objectWillChange.send()
    }

    // MARK: - Filtering

    private func filterSites(for kind: PermissionKind, allowed: Bool) -> [SitePermission] {
        switch kind {
        case .camera:
            return sitePermissions.filter { $0.cameraAllowed == allowed }
        case .microphone:
            return sitePermissions.filter { $0.microphoneAllowed == allowed }
        }
    }

    func allowedSites(for kind: PermissionKind) -> [SitePermission] {
        filterSites(for: kind, allowed: true)
    }

    func notAllowedSites(for kind: PermissionKind) -> [SitePermission] {
        filterSites(for: kind, allowed: false)
    }

    // MARK: - Mutations

    func addOrUpdateSite(host: String, allow: Bool, for kind: PermissionKind) {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var entry = sitePermissions.first {
            $0.host.caseInsensitiveCompare(normalized) == .orderedSame
        }

        if entry == nil {
            entry = SitePermission(host: normalized)
            context.insert(entry!)
            sitePermissions.append(entry!)
        }

        switch kind {
        case .camera:
            entry?.cameraAllowed = allow
            entry?.cameraConfigured = true
        case .microphone:
            entry?.microphoneAllowed = allow
            entry?.microphoneConfigured = true
        }

        saveContext()
        // Refresh permissions from context to ensure we have the latest data
        refreshPermissions()
    }

    func removeSite(host: String) {
        guard let idx = sitePermissions.firstIndex(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) else { return }

        let entry = sitePermissions.remove(at: idx)
        context.delete(entry)
        saveContext()
        objectWillChange.send()
    }

    // MARK: - Persistence

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("❌ Failed to save permissions: \(error)")
        }
    }
}
