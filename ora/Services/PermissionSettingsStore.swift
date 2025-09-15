import Foundation
import SwiftData

enum PermissionKind: CaseIterable {
    case location, camera, microphone, notifications
    case embeddedContent, backgroundSync, motionSensors, automaticDownloads
    case protocolHandlers, midiDevice, usbDevices, serialPorts
    case fileEditing, hidDevices, clipboard, paymentHandlers
    case augmentedReality, virtualReality, deviceUse, windowManagement
    case fonts, automaticPictureInPicture, scrollingZoomingSharedTabs
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
        case .location: return sitePermissions.filter { $0.locationAllowed == allowed }
        case .camera: return sitePermissions.filter { $0.cameraAllowed == allowed }
        case .microphone: return sitePermissions.filter { $0.microphoneAllowed == allowed }
        case .notifications: return sitePermissions.filter { $0.notificationsAllowed == allowed }
        case .embeddedContent: return sitePermissions.filter { $0.embeddedContentAllowed == allowed }
        case .backgroundSync: return sitePermissions.filter { $0.backgroundSyncAllowed == allowed }
        case .motionSensors: return sitePermissions.filter { $0.motionSensorsAllowed == allowed }
        case .automaticDownloads: return sitePermissions.filter { $0.automaticDownloadsAllowed == allowed }
        case .protocolHandlers: return sitePermissions.filter { $0.protocolHandlersAllowed == allowed }
        case .midiDevice: return sitePermissions.filter { $0.midiDeviceAllowed == allowed }
        case .usbDevices: return sitePermissions.filter { $0.usbDevicesAllowed == allowed }
        case .serialPorts: return sitePermissions.filter { $0.serialPortsAllowed == allowed }
        case .fileEditing: return sitePermissions.filter { $0.fileEditingAllowed == allowed }
        case .hidDevices: return sitePermissions.filter { $0.hidDevicesAllowed == allowed }
        case .clipboard: return sitePermissions.filter { $0.clipboardAllowed == allowed }
        case .paymentHandlers: return sitePermissions.filter { $0.paymentHandlersAllowed == allowed }
        case .augmentedReality: return sitePermissions.filter { $0.augmentedRealityAllowed == allowed }
        case .virtualReality: return sitePermissions.filter { $0.virtualRealityAllowed == allowed }
        case .deviceUse: return sitePermissions.filter { $0.deviceUseAllowed == allowed }
        case .windowManagement: return sitePermissions.filter { $0.windowManagementAllowed == allowed }
        case .fonts: return sitePermissions.filter { $0.fontsAllowed == allowed }
        case .automaticPictureInPicture: return sitePermissions
            .filter { $0.automaticPictureInPictureAllowed == allowed }
        case .scrollingZoomingSharedTabs: return sitePermissions
            .filter { $0.scrollingZoomingSharedTabsAllowed == allowed }
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
        case .location:
            entry?.locationAllowed = allow
            entry?.locationConfigured = true
        case .camera:
            entry?.cameraAllowed = allow
            entry?.cameraConfigured = true
        case .microphone:
            entry?.microphoneAllowed = allow
            entry?.microphoneConfigured = true
        case .notifications:
            entry?.notificationsAllowed = allow
            entry?.notificationsConfigured = true
        case .embeddedContent:
            entry?.embeddedContentAllowed = allow
            entry?.embeddedContentConfigured = true
        case .backgroundSync:
            entry?.backgroundSyncAllowed = allow
            entry?.backgroundSyncConfigured = true
        case .motionSensors:
            entry?.motionSensorsAllowed = allow
            entry?.motionSensorsConfigured = true
        case .automaticDownloads:
            entry?.automaticDownloadsAllowed = allow
            entry?.automaticDownloadsConfigured = true
        case .protocolHandlers:
            entry?.protocolHandlersAllowed = allow
            entry?.protocolHandlersConfigured = true
        case .midiDevice:
            entry?.midiDeviceAllowed = allow
            entry?.midiDeviceConfigured = true
        case .usbDevices:
            entry?.usbDevicesAllowed = allow
            entry?.usbDevicesConfigured = true
        case .serialPorts:
            entry?.serialPortsAllowed = allow
            entry?.serialPortsConfigured = true
        case .fileEditing:
            entry?.fileEditingAllowed = allow
            entry?.fileEditingConfigured = true
        case .hidDevices:
            entry?.hidDevicesAllowed = allow
            entry?.hidDevicesConfigured = true
        case .clipboard:
            entry?.clipboardAllowed = allow
            entry?.clipboardConfigured = true
        case .paymentHandlers:
            entry?.paymentHandlersAllowed = allow
            entry?.paymentHandlersConfigured = true
        case .augmentedReality:
            entry?.augmentedRealityAllowed = allow
            entry?.augmentedRealityConfigured = true
        case .virtualReality:
            entry?.virtualRealityAllowed = allow
            entry?.virtualRealityConfigured = true
        case .deviceUse:
            entry?.deviceUseAllowed = allow
            entry?.deviceUseConfigured = true
        case .windowManagement:
            entry?.windowManagementAllowed = allow
            entry?.windowManagementConfigured = true
        case .fonts:
            entry?.fontsAllowed = allow
            entry?.fontsConfigured = true
        case .automaticPictureInPicture:
            entry?.automaticPictureInPictureAllowed = allow
            entry?.automaticPictureInPictureConfigured = true
        case .scrollingZoomingSharedTabs:
            entry?.scrollingZoomingSharedTabsAllowed = allow
            entry?.scrollingZoomingSharedTabsConfigured = true
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
