import SwiftData
import SwiftUI

struct SiteSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAdditionalExpanded: Bool = false
    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 0) {
                    InlineBackButton(action: { dismiss() })
                        .padding(.bottom, 8)
                    PermissionRow(
                        title: "Location",
                        subtitle: "Sites can ask for your location",
                        systemImage: "location"
                    ) {
                        LocationPermissionView()
                    }

                    PermissionRow(
                        title: "Camera",
                        subtitle: "Sites can ask to use your camera",
                        systemImage: "camera"
                    ) {
                        CameraPermissionView()
                    }

                    PermissionRow(
                        title: "Microphone",
                        subtitle: "Sites can ask to use your microphone",
                        systemImage: "mic"
                    ) {
                        MicrophonePermissionView()
                    }

                    PermissionRow(
                        title: "Notifications",
                        subtitle: "Collapse unwanted requests (recommended)",
                        systemImage: "bell"
                    ) {
                        NotificationsPermissionView()
                    }

                    PermissionRow(
                        title: "Embedded content",
                        subtitle: "Sites can ask to use information they've saved about you",
                        systemImage: "rectangle.on.rectangle"
                    ) {
                        EmbeddedContentPermissionView()
                    }

                    DisclosureGroup(isExpanded: $isAdditionalExpanded) {
                        VStack(spacing: 0) {
                            PermissionRow(
                                title: "Background sync",
                                subtitle: "Recently closed sites can finish sending and receiving data",
                                systemImage: "arrow.triangle.2.circlepath"
                            ) {
                                BackgroundSyncPermissionView()
                            }
                            PermissionRow(
                                title: "Motion sensors",
                                subtitle: "Sites can use motion sensors",
                                systemImage: "waveform.path.ecg"
                            ) {
                                MotionSensorsPermissionView()
                            }
                            PermissionRow(
                                title: "Automatic downloads",
                                subtitle: "Sites can ask to automatically download multiple files",
                                systemImage: "arrow.down.circle"
                            ) {
                                AutomaticDownloadsPermissionView()
                            }
                            PermissionRow(
                                title: "Protocol handlers",
                                subtitle: "Sites can ask to handle protocols",
                                systemImage: "link"
                            ) {
                                UnifiedPermissionView(
                                    title: "Protocol handlers",
                                    description: "Sites can ask to handle protocols",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "MIDI device control & reprogram",
                                subtitle: "Sites can ask to control and reprogram your MIDI devices",
                                systemImage: "airpodspro"
                            ) {
                                UnifiedPermissionView(
                                    title: "MIDI device control & reprogram",
                                    description: "Sites can ask to control and reprogram your MIDI devices",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "USB devices",
                                subtitle: "Sites can ask to connect to USB devices",
                                systemImage: "externaldrive"
                            ) {
                                UnifiedPermissionView(
                                    title: "USB devices",
                                    description: "Sites can ask to connect to USB devices",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Serial ports",
                                subtitle: "Sites can ask to connect to serial ports",
                                systemImage: "cable.connector.horizontal"
                            ) {
                                UnifiedPermissionView(
                                    title: "Serial ports",
                                    description: "Sites can ask to connect to serial ports",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "File editing",
                                subtitle: "Sites can ask to edit files and folders on your device",
                                systemImage: "folder"
                            ) {
                                UnifiedPermissionView(
                                    title: "File editing",
                                    description: "Sites can ask to edit files and folders on your device",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "HID devices",
                                subtitle: "Ask when a site wants to access HID devices",
                                systemImage: "dot.radiowaves.left.and.right"
                            ) {
                                UnifiedPermissionView(
                                    title: "HID devices",
                                    description: "Ask when a site wants to access HID devices",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Clipboard",
                                subtitle: "Sites can ask to see text and images on your clipboard",
                                systemImage: "clipboard"
                            ) {
                                UnifiedPermissionView(
                                    title: "Clipboard",
                                    description: "Sites can ask to see text and images on your clipboard",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Payment handlers",
                                subtitle: "Sites can install payment handlers",
                                systemImage: "creditcard"
                            ) {
                                UnifiedPermissionView(
                                    title: "Payment handlers",
                                    description: "Sites can install payment handlers",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Augmented reality",
                                subtitle: "Ask when a site wants to create a 3D map of your surroundings or track camera position",
                                systemImage: "arkit"
                            ) {
                                UnifiedPermissionView(
                                    title: "Augmented reality",
                                    description: "Ask when a site wants to create a 3D map of your surroundings or track camera position",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Virtual reality",
                                subtitle: "Sites can ask to use virtual reality devices and data",
                                systemImage: "visionpro"
                            ) {
                                UnifiedPermissionView(
                                    title: "Virtual reality",
                                    description: "Sites can ask to use virtual reality devices and data",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Your device use",
                                subtitle: "Sites can ask to know when you're actively using your device",
                                systemImage: "cursorarrow.rays"
                            ) {
                                UnifiedPermissionView(
                                    title: "Your device use",
                                    description: "Sites can ask to know when you're actively using your device",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Window management",
                                subtitle: "Sites can ask to manage windows on all your displays",
                                systemImage: "macwindow.on.rectangle"
                            ) {
                                UnifiedPermissionView(
                                    title: "Window management",
                                    description: "Sites can ask to manage windows on all your displays",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Fonts",
                                subtitle: "Sites can ask to use fonts installed on your device",
                                systemImage: "textformat"
                            ) {
                                UnifiedPermissionView(
                                    title: "Fonts",
                                    description: "Sites can ask to use fonts installed on your device",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Automatic picture-in-picture",
                                subtitle: "Sites can enter picture-in-picture automatically",
                                systemImage: "pip"
                            ) {
                                UnifiedPermissionView(
                                    title: "Automatic picture-in-picture",
                                    description: "Sites can enter picture-in-picture automatically",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                            PermissionRow(
                                title: "Scrolling and zooming shared tabs",
                                subtitle: "Sites can ask to scroll and zoom shared tabs",
                                systemImage: "magnifyingglass"
                            ) {
                                UnifiedPermissionView(
                                    title: "Scrolling and zooming shared tabs",
                                    description: "Sites can ask to scroll and zoom shared tabs",
                                    permissionKind: nil,
                                    allowedText: nil,
                                    blockedText: nil
                                )
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Text("Additional permissions")
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isAdditionalExpanded.toggle() }
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
}

private struct PermissionRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        Divider()
    }
}

// MARK: - Permission detail screens

struct UnifiedPermissionView: View {
    let title: String
    let description: String
    let permissionKind: PermissionKind?
    let allowedText: String?
    let blockedText: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SitePermission.host) private var allSitePermissions: [SitePermission]
    @State private var searchText: String = ""

    private var allowedSites: [SitePermission] {
        guard let permissionKind else { return [] }

        let filtered = allSitePermissions.filter { site in
            switch permissionKind {
            case .location: return site.locationConfigured && site.locationAllowed
            case .camera: return site.cameraConfigured && site.cameraAllowed
            case .microphone: return site.microphoneConfigured && site.microphoneAllowed
            case .notifications: return site.notificationsConfigured && site.notificationsAllowed
            }
        }

        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var blockedSites: [SitePermission] {
        guard let permissionKind else { return [] }

        let filtered = allSitePermissions.filter { site in
            switch permissionKind {
            case .location: return site.locationConfigured && !site.locationAllowed
            case .camera: return site.cameraConfigured && !site.cameraAllowed
            case .microphone: return site.microphoneConfigured && !site.microphoneAllowed
            case .notifications: return site.notificationsConfigured && !site.notificationsAllowed
            }
        }

        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                InlineBackButton(action: { dismiss() })

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search sites...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 200)
            }

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(description)
                .foregroundStyle(.secondary)

            Group {
                Text("Customized behaviors").font(.headline)

                if permissionKind != nil {
                    if !blockedSites.isEmpty {
                        Text(blockedText ?? "Blocked sites").font(.subheadline)
                        ForEach(blockedSites, id: \.host) { entry in
                            SiteRow(entry: entry, onRemove: { removeSite(entry) })
                        }
                    }

                    if !allowedSites.isEmpty {
                        Text(allowedText ?? "Allowed sites").font(.subheadline)
                        ForEach(allowedSites, id: \.host) { entry in
                            SiteRow(entry: entry, onRemove: { removeSite(entry) })
                        }
                    }

                    if allowedSites.isEmpty, blockedSites.isEmpty {
                        Text("No sites configured yet.").foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No sites configured yet.").foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func removeSite(_ site: SitePermission) {
        modelContext.delete(site)
        try? modelContext.save()
    }
}

struct LocationPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Location",
            description: "Sites usually use your location for relevant features or info, like local news or nearby shops",
            permissionKind: .location,
            allowedText: "Allowed to see your location",
            blockedText: "Not allowed to see your location"
        )
    }
}

private struct SiteRow: View {
    let entry: SitePermission
    let onRemove: () -> Void
    var body: some View {
        HStack {
            Text(entry.host)
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

private struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
        }
        .buttonStyle(.plain)
    }
}

struct CameraPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Camera",
            description: "Sites can ask to use your camera for video calls, photos, and other features",
            permissionKind: .camera,
            allowedText: "Allowed to use your camera",
            blockedText: "Not allowed to use your camera"
        )
    }
}

struct MicrophonePermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Microphone",
            description: "Sites can ask to use your microphone for voice calls, recordings, and audio features",
            permissionKind: .microphone,
            allowedText: "Allowed to use your microphone",
            blockedText: "Not allowed to use your microphone"
        )
    }
}

struct NotificationsPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Notifications",
            description: "Sites can ask to send you notifications for updates, messages, and alerts",
            permissionKind: .notifications,
            allowedText: "Allowed to send notifications",
            blockedText: "Not allowed to send notifications"
        )
    }
}

struct EmbeddedContentPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Embedded content",
            description: "Sites can ask to use information they've saved about you",
            permissionKind: nil,
            allowedText: nil,
            blockedText: nil
        )
    }
}

// MARK: - Additional Permission Views

struct BackgroundSyncPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Background sync",
            description: "Recently closed sites can finish sending and receiving data",
            permissionKind: nil,
            allowedText: nil,
            blockedText: nil
        )
    }
}

struct MotionSensorsPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Motion sensors",
            description: "Sites can use motion sensors",
            permissionKind: nil,
            allowedText: nil,
            blockedText: nil
        )
    }
}

struct AutomaticDownloadsPermissionView: View {
    var body: some View {
        UnifiedPermissionView(
            title: "Automatic downloads",
            description: "Sites can ask to automatically download multiple files",
            permissionKind: nil,
            allowedText: nil,
            blockedText: nil
        )
    }
}

// MARK: - Inline Back Button

private struct InlineBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}
