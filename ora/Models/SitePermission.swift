import Foundation
import SwiftData

@Model
final class SitePermission {
    @Attribute(.unique) var host: String

    // Permissions
    var cameraAllowed: Bool
    var microphoneAllowed: Bool

    // Track which permissions have been explicitly set
    var cameraConfigured: Bool
    var microphoneConfigured: Bool

    init(
        host: String,
        cameraAllowed: Bool = false,
        microphoneAllowed: Bool = false
    ) {
        self.host = host
        self.cameraAllowed = cameraAllowed
        self.microphoneAllowed = microphoneAllowed
        self.cameraConfigured = false
        self.microphoneConfigured = false
    }
}
