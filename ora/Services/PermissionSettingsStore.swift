import Foundation
import SwiftData

enum PermissionKind: CaseIterable {
    case location, camera, microphone, notifications
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

    // MARK: - Filtering

    private func filterSites(for kind: PermissionKind, allowed: Bool) -> [SitePermission] {
        switch kind {
        case .location: return sitePermissions.filter { $0.locationAllowed == allowed }
        case .camera: return sitePermissions.filter { $0.cameraAllowed == allowed }
        case .microphone: return sitePermissions.filter { $0.microphoneAllowed == allowed }
        case .notifications: return sitePermissions.filter { $0.notificationsAllowed == allowed }
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
        case .location: entry?.locationAllowed = allow
        case .camera: entry?.cameraAllowed = allow
        case .microphone: entry?.microphoneAllowed = allow
        case .notifications: entry?.notificationsAllowed = allow
        }

        saveContext()
        sitePermissions.sort { $0.host.lowercased() < $1.host.lowercased() }
        // trigger update
        objectWillChange.send()
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
