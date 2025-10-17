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
        case .camera:
            return site.cameraConfigured ? site.cameraAllowed : getDefaultPermissionValue(for: type)
        case .microphone:
            return site.microphoneConfigured ? site.microphoneAllowed : getDefaultPermissionValue(for: type)
        }
    }

    private func getDefaultPermissionValue(for type: PermissionKind) -> Bool? {
        // Always show dialog for camera and microphone permissions
        return nil
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
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        }
    }

    var description: String {
        switch self {
        case .camera: return "Use your camera"
        case .microphone: return "Use your microphone"
        }
    }

    var iconName: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "mic"
        }
    }
}
