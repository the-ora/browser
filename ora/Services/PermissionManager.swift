import Foundation
import SwiftUI
import WebKit

@MainActor
class PermissionManager: NSObject, ObservableObject {
    static let shared = PermissionManager()

    @Published var pendingRequest: PermissionRequest?
    @Published var showPermissionDialog = false

    override private init() {
        super.init()
    }

    func requestPermission(
        for permissionType: PermissionKind,
        from host: String,
        webView: WKWebView,
        completion: @escaping (Bool) -> Void
    ) {
        print("🔧 PermissionManager: Requesting \(permissionType) for \(host)")

        let request = PermissionRequest(
            permissionType: permissionType,
            host: host,
            webView: webView,
            completion: completion
        )

        // Check if permission is already configured
        if let existingPermission = getExistingPermission(for: host, type: permissionType) {
            print("🔧 Using existing permission: \(existingPermission)")
            completion(existingPermission)
            return
        }

        // Check if there's already a pending request
        if pendingRequest != nil {
            print("🔧 Already have pending request, waiting for it to complete...")
            // Wait for the current request to complete, then try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestPermission(for: permissionType, from: host, webView: webView, completion: completion)
            }
            return
        }

        print("🔧 Showing permission dialog for \(permissionType)")
        // Show permission dialog
        self.pendingRequest = request
        self.showPermissionDialog = true

        // Safety timeout to ensure completion is always called
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.pendingRequest?.completion != nil,
               self.pendingRequest?.host == request.host,
               self.pendingRequest?.permissionType == request.permissionType
            {
                // Request timed out, call completion with false and clear
                request.completion(false)
                self.pendingRequest = nil
                self.showPermissionDialog = false
            }
        }
    }

    func handlePermissionResponse(allow: Bool) {
        guard let request = pendingRequest else {
            print("🔧 ERROR: No pending request to handle")
            return
        }

        print("🔧 Handling response: \(allow) for \(request.permissionType)")

        // Update permission store
        PermissionSettingsStore.shared.addOrUpdateSite(
            host: request.host,
            allow: allow,
            for: request.permissionType
        )

        // Call completion
        request.completion(allow)

        // Clear pending request
        self.pendingRequest = nil
        self.showPermissionDialog = false

        print("🔧 Permission dialog cleared, ready for next request")
    }

    func getExistingPermission(for host: String, type: PermissionKind) -> Bool? {
        let sites = PermissionSettingsStore.shared.sitePermissions

        guard let site = sites.first(where: { $0.host.caseInsensitiveCompare(host) == .orderedSame }) else {
            // No site entry exists, return default value for permissions that should be allowed by default
            return getDefaultPermissionValue(for: type)
        }

        switch type {
        case .location: return site.locationConfigured ? site.locationAllowed : getDefaultPermissionValue(for: type)
        case .camera: return site.cameraConfigured ? site.cameraAllowed : getDefaultPermissionValue(for: type)
        case .microphone: return site.microphoneConfigured ? site
            .microphoneAllowed : getDefaultPermissionValue(for: type)
        case .notifications: return site.notificationsConfigured ? site
            .notificationsAllowed : getDefaultPermissionValue(for: type)
        case .embeddedContent: return site.embeddedContentConfigured ? site
            .embeddedContentAllowed : getDefaultPermissionValue(for: type)
        case .backgroundSync: return site.backgroundSyncConfigured ? site
            .backgroundSyncAllowed : getDefaultPermissionValue(for: type)
        case .motionSensors: return site.motionSensorsConfigured ? site
            .motionSensorsAllowed : getDefaultPermissionValue(for: type)
        case .automaticDownloads: return site.automaticDownloadsConfigured ? site
            .automaticDownloadsAllowed : getDefaultPermissionValue(for: type)
        case .protocolHandlers: return site.protocolHandlersConfigured ? site
            .protocolHandlersAllowed : getDefaultPermissionValue(for: type)
        case .midiDevice: return site.midiDeviceConfigured ? site
            .midiDeviceAllowed : getDefaultPermissionValue(for: type)
        case .usbDevices: return site.usbDevicesConfigured ? site
            .usbDevicesAllowed : getDefaultPermissionValue(for: type)
        case .serialPorts: return site.serialPortsConfigured ? site
            .serialPortsAllowed : getDefaultPermissionValue(for: type)
        case .fileEditing: return site.fileEditingConfigured ? site
            .fileEditingAllowed : getDefaultPermissionValue(for: type)
        case .hidDevices: return site.hidDevicesConfigured ? site
            .hidDevicesAllowed : getDefaultPermissionValue(for: type)
        case .clipboard: return site.clipboardConfigured ? site.clipboardAllowed : getDefaultPermissionValue(for: type)
        case .paymentHandlers: return site.paymentHandlersConfigured ? site
            .paymentHandlersAllowed : getDefaultPermissionValue(for: type)
        case .augmentedReality: return site.augmentedRealityConfigured ? site
            .augmentedRealityAllowed : getDefaultPermissionValue(for: type)
        case .virtualReality: return site.virtualRealityConfigured ? site
            .virtualRealityAllowed : getDefaultPermissionValue(for: type)
        case .deviceUse: return site.deviceUseConfigured ? site.deviceUseAllowed : getDefaultPermissionValue(for: type)
        case .windowManagement: return site.windowManagementConfigured ? site
            .windowManagementAllowed : getDefaultPermissionValue(for: type)
        case .fonts: return site.fontsConfigured ? site.fontsAllowed : getDefaultPermissionValue(for: type)
        case .automaticPictureInPicture: return site.automaticPictureInPictureConfigured ? site
            .automaticPictureInPictureAllowed : getDefaultPermissionValue(for: type)
        case .scrollingZoomingSharedTabs: return site.scrollingZoomingSharedTabsConfigured ? site
            .scrollingZoomingSharedTabsAllowed : getDefaultPermissionValue(for: type)
        }
    }

    private func getDefaultPermissionValue(for type: PermissionKind) -> Bool? {
        switch type {
        case .backgroundSync:
            return true  // Allow background sync by default
        default:
            return nil   // Show dialog for all other permissions
        }
    }
}

struct PermissionRequest {
    let permissionType: PermissionKind
    let host: String
    let webView: WKWebView
    let completion: (Bool) -> Void
}

extension PermissionKind {
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .notifications: return "Notifications"
        case .embeddedContent: return "Embedded Content"
        case .backgroundSync: return "Background Sync"
        case .motionSensors: return "Motion Sensors"
        case .automaticDownloads: return "Automatic Downloads"
        case .protocolHandlers: return "Protocol Handlers"
        case .midiDevice: return "MIDI Device Control"
        case .usbDevices: return "USB Devices"
        case .serialPorts: return "Serial Ports"
        case .fileEditing: return "File Editing"
        case .hidDevices: return "HID Devices"
        case .clipboard: return "Clipboard"
        case .paymentHandlers: return "Payment Handlers"
        case .augmentedReality: return "Augmented Reality"
        case .virtualReality: return "Virtual Reality"
        case .deviceUse: return "Device Use Tracking"
        case .windowManagement: return "Window Management"
        case .fonts: return "Fonts"
        case .automaticPictureInPicture: return "Automatic Picture-in-Picture"
        case .scrollingZoomingSharedTabs: return "Scrolling and Zooming Shared Tabs"
        }
    }

    var description: String {
        switch self {
        case .location: return "Access your location"
        case .camera: return "Use your camera"
        case .microphone: return "Use your microphone"
        case .notifications: return "Send you notifications"
        case .embeddedContent: return "Use embedded content"
        case .backgroundSync: return "Sync data in the background"
        case .motionSensors: return "Access motion sensors"
        case .automaticDownloads: return "Automatically download files"
        case .protocolHandlers: return "Handle custom protocols"
        case .midiDevice: return "Control MIDI devices"
        case .usbDevices: return "Connect to USB devices"
        case .serialPorts: return "Connect to serial ports"
        case .fileEditing: return "Edit files on your device"
        case .hidDevices: return "Access HID devices"
        case .clipboard: return "Access your clipboard"
        case .paymentHandlers: return "Install payment handlers"
        case .augmentedReality: return "Use augmented reality features"
        case .virtualReality: return "Use virtual reality features"
        case .deviceUse: return "Track when you're using your device"
        case .windowManagement: return "Manage windows on your displays"
        case .fonts: return "Access fonts on your device"
        case .automaticPictureInPicture: return "Enter picture-in-picture automatically"
        case .scrollingZoomingSharedTabs: return "Scroll and zoom shared tabs"
        }
    }

    var iconName: String {
        switch self {
        case .location: return "location"
        case .camera: return "camera"
        case .microphone: return "mic"
        case .notifications: return "bell"
        case .embeddedContent: return "rectangle.on.rectangle"
        case .backgroundSync: return "arrow.triangle.2.circlepath"
        case .motionSensors: return "waveform.path.ecg"
        case .automaticDownloads: return "arrow.down.circle"
        case .protocolHandlers: return "link"
        case .midiDevice: return "airpodspro"
        case .usbDevices: return "externaldrive"
        case .serialPorts: return "cable.connector.horizontal"
        case .fileEditing: return "folder"
        case .hidDevices: return "dot.radiowaves.left.and.right"
        case .clipboard: return "clipboard"
        case .paymentHandlers: return "creditcard"
        case .augmentedReality: return "arkit"
        case .virtualReality: return "visionpro"
        case .deviceUse: return "cursorarrow.rays"
        case .windowManagement: return "macwindow.on.rectangle"
        case .fonts: return "textformat"
        case .automaticPictureInPicture: return "pip"
        case .scrollingZoomingSharedTabs: return "magnifyingglass"
        }
    }
}
