import Foundation
import SwiftData

@Model
final class SitePermission {
    @Attribute(.unique) var host: String
    var locationAllowed: Bool
    var cameraAllowed: Bool
    var microphoneAllowed: Bool
    var notificationsAllowed: Bool

    init(
        host: String,
        locationAllowed: Bool = true,
        cameraAllowed: Bool = true,
        microphoneAllowed: Bool = true,
        notificationsAllowed: Bool = true
    ) {
        self.host = host
        self.locationAllowed = locationAllowed
        self.cameraAllowed = cameraAllowed
        self.microphoneAllowed = microphoneAllowed
        self.notificationsAllowed = notificationsAllowed
    }
}
