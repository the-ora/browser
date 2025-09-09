import Foundation
import SwiftData

@Model
final class SitePermission {
    @Attribute(.unique) var host: String

    // Main permissions
    var locationAllowed: Bool
    var cameraAllowed: Bool
    var microphoneAllowed: Bool
    var notificationsAllowed: Bool

    // Additional permissions
    var embeddedContentAllowed: Bool
    var backgroundSyncAllowed: Bool
    var motionSensorsAllowed: Bool
    var automaticDownloadsAllowed: Bool
    var protocolHandlersAllowed: Bool
    var midiDeviceAllowed: Bool
    var usbDevicesAllowed: Bool
    var serialPortsAllowed: Bool
    var fileEditingAllowed: Bool
    var hidDevicesAllowed: Bool
    var clipboardAllowed: Bool
    var paymentHandlersAllowed: Bool
    var augmentedRealityAllowed: Bool
    var virtualRealityAllowed: Bool
    var deviceUseAllowed: Bool
    var windowManagementAllowed: Bool
    var fontsAllowed: Bool
    var automaticPictureInPictureAllowed: Bool
    var scrollingZoomingSharedTabsAllowed: Bool

    // Track which permissions have been explicitly set
    var locationConfigured: Bool
    var cameraConfigured: Bool
    var microphoneConfigured: Bool
    var notificationsConfigured: Bool
    var embeddedContentConfigured: Bool
    var backgroundSyncConfigured: Bool
    var motionSensorsConfigured: Bool
    var automaticDownloadsConfigured: Bool
    var protocolHandlersConfigured: Bool
    var midiDeviceConfigured: Bool
    var usbDevicesConfigured: Bool
    var serialPortsConfigured: Bool
    var fileEditingConfigured: Bool
    var hidDevicesConfigured: Bool
    var clipboardConfigured: Bool
    var paymentHandlersConfigured: Bool
    var augmentedRealityConfigured: Bool
    var virtualRealityConfigured: Bool
    var deviceUseConfigured: Bool
    var windowManagementConfigured: Bool
    var fontsConfigured: Bool
    var automaticPictureInPictureConfigured: Bool
    var scrollingZoomingSharedTabsConfigured: Bool

    init(
        host: String,
        locationAllowed: Bool = false,
        cameraAllowed: Bool = false,
        microphoneAllowed: Bool = false,
        notificationsAllowed: Bool = false,
        embeddedContentAllowed: Bool = false,
        backgroundSyncAllowed: Bool = false,
        motionSensorsAllowed: Bool = false,
        automaticDownloadsAllowed: Bool = false,
        protocolHandlersAllowed: Bool = false,
        midiDeviceAllowed: Bool = false,
        usbDevicesAllowed: Bool = false,
        serialPortsAllowed: Bool = false,
        fileEditingAllowed: Bool = false,
        hidDevicesAllowed: Bool = false,
        clipboardAllowed: Bool = false,
        paymentHandlersAllowed: Bool = false,
        augmentedRealityAllowed: Bool = false,
        virtualRealityAllowed: Bool = false,
        deviceUseAllowed: Bool = false,
        windowManagementAllowed: Bool = false,
        fontsAllowed: Bool = false,
        automaticPictureInPictureAllowed: Bool = false,
        scrollingZoomingSharedTabsAllowed: Bool = false
    ) {
        self.host = host
        self.locationAllowed = locationAllowed
        self.cameraAllowed = cameraAllowed
        self.microphoneAllowed = microphoneAllowed
        self.notificationsAllowed = notificationsAllowed
        self.embeddedContentAllowed = embeddedContentAllowed
        self.backgroundSyncAllowed = backgroundSyncAllowed
        self.motionSensorsAllowed = motionSensorsAllowed
        self.automaticDownloadsAllowed = automaticDownloadsAllowed
        self.protocolHandlersAllowed = protocolHandlersAllowed
        self.midiDeviceAllowed = midiDeviceAllowed
        self.usbDevicesAllowed = usbDevicesAllowed
        self.serialPortsAllowed = serialPortsAllowed
        self.fileEditingAllowed = fileEditingAllowed
        self.hidDevicesAllowed = hidDevicesAllowed
        self.clipboardAllowed = clipboardAllowed
        self.paymentHandlersAllowed = paymentHandlersAllowed
        self.augmentedRealityAllowed = augmentedRealityAllowed
        self.virtualRealityAllowed = virtualRealityAllowed
        self.deviceUseAllowed = deviceUseAllowed
        self.windowManagementAllowed = windowManagementAllowed
        self.fontsAllowed = fontsAllowed
        self.automaticPictureInPictureAllowed = automaticPictureInPictureAllowed
        self.scrollingZoomingSharedTabsAllowed = scrollingZoomingSharedTabsAllowed

        // Initially, no permissions are configured
        self.locationConfigured = false
        self.cameraConfigured = false
        self.microphoneConfigured = false
        self.notificationsConfigured = false
        self.embeddedContentConfigured = false
        self.backgroundSyncConfigured = false
        self.motionSensorsConfigured = false
        self.automaticDownloadsConfigured = false
        self.protocolHandlersConfigured = false
        self.midiDeviceConfigured = false
        self.usbDevicesConfigured = false
        self.serialPortsConfigured = false
        self.fileEditingConfigured = false
        self.hidDevicesConfigured = false
        self.clipboardConfigured = false
        self.paymentHandlersConfigured = false
        self.augmentedRealityConfigured = false
        self.virtualRealityConfigured = false
        self.deviceUseConfigured = false
        self.windowManagementConfigured = false
        self.fontsConfigured = false
        self.automaticPictureInPictureConfigured = false
        self.scrollingZoomingSharedTabsConfigured = false
    }
}
