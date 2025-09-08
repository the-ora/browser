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
                                AdditionalPermissionListView(title: "Background sync")
                            }
                            PermissionRow(
                                title: "Motion sensors",
                                subtitle: "Sites can use motion sensors",
                                systemImage: "waveform.path.ecg"
                            ) {
                                AdditionalPermissionListView(title: "Motion sensors")
                            }
                            PermissionRow(
                                title: "Automatic downloads",
                                subtitle: "Sites can ask to automatically download multiple files",
                                systemImage: "arrow.down.circle"
                            ) {
                                AdditionalPermissionListView(title: "Automatic downloads")
                            }
                            PermissionRow(
                                title: "Protocol handlers",
                                subtitle: "Sites can ask to handle protocols",
                                systemImage: "link"
                            ) {
                                AdditionalPermissionListView(title: "Protocol handlers")
                            }
                            PermissionRow(
                                title: "MIDI device control & reprogram",
                                subtitle: "Sites can ask to control and reprogram your MIDI devices",
                                systemImage: "pianokeys"
                            ) {
                                AdditionalPermissionListView(title: "MIDI device control & reprogram")
                            }
                            PermissionRow(
                                title: "USB devices",
                                subtitle: "Sites can ask to connect to USB devices",
                                systemImage: "externaldrive"
                            ) {
                                AdditionalPermissionListView(title: "USB devices")
                            }
                            PermissionRow(
                                title: "Serial ports",
                                subtitle: "Sites can ask to connect to serial ports",
                                systemImage: "cable.connector.horizontal"
                            ) {
                                AdditionalPermissionListView(title: "Serial ports")
                            }
                            PermissionRow(
                                title: "File editing",
                                subtitle: "Sites can ask to edit files and folders on your device",
                                systemImage: "folder"
                            ) {
                                AdditionalPermissionListView(title: "File editing")
                            }
                            PermissionRow(
                                title: "HID devices",
                                subtitle: "Ask when a site wants to access HID devices",
                                systemImage: "dot.radiowaves.left.and.right"
                            ) {
                                AdditionalPermissionListView(title: "HID devices")
                            }
                            PermissionRow(
                                title: "Clipboard",
                                subtitle: "Sites can ask to see text and images on your clipboard",
                                systemImage: "clipboard"
                            ) {
                                AdditionalPermissionListView(title: "Clipboard")
                            }
                            PermissionRow(
                                title: "Payment handlers",
                                subtitle: "Sites can install payment handlers",
                                systemImage: "creditcard"
                            ) {
                                AdditionalPermissionListView(title: "Payment handlers")
                            }
                            PermissionRow(
                                title: "Augmented reality",
                                subtitle: "Ask when a site wants to create a 3D map of your surroundings or track camera position",
                                systemImage: "arkit"
                            ) {
                                AdditionalPermissionListView(title: "Augmented reality")
                            }
                            PermissionRow(
                                title: "Virtual reality",
                                subtitle: "Sites can ask to use virtual reality devices and data",
                                systemImage: "visionpro"
                            ) {
                                AdditionalPermissionListView(title: "Virtual reality")
                            }
                            PermissionRow(
                                title: "Your device use",
                                subtitle: "Sites can ask to know when you're actively using your device",
                                systemImage: "cursorarrow.rays"
                            ) {
                                AdditionalPermissionListView(title: "Your device use")
                            }
                            PermissionRow(
                                title: "Window management",
                                subtitle: "Sites can ask to manage windows on all your displays",
                                systemImage: "macwindow.on.rectangle"
                            ) {
                                AdditionalPermissionListView(title: "Window management")
                            }
                            PermissionRow(
                                title: "Fonts",
                                subtitle: "Sites can ask to use fonts installed on your device",
                                systemImage: "textformat"
                            ) {
                                AdditionalPermissionListView(title: "Fonts")
                            }
                            PermissionRow(
                                title: "Automatic picture-in-picture",
                                subtitle: "Sites can enter picture-in-picture automatically",
                                systemImage: "pip"
                            ) {
                                AdditionalPermissionListView(title: "Automatic picture-in-picture")
                            }
                            PermissionRow(
                                title: "Scrolling and zooming shared tabs",
                                subtitle: "Sites can ask to scroll and zoom shared tabs",
                                systemImage: "magnifyingglass"
                            ) {
                                AdditionalPermissionListView(title: "Scrolling and zooming shared tabs")
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

struct DynamicPermissionView: View {
    let permissionKind: PermissionKind
    let title: String
    let description: String
    let allowedText: String
    let blockedText: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SitePermission.host) private var allSitePermissions: [SitePermission]
    @State private var newHost: String = ""
    @State private var newPolicyAllow: Bool = true

    private var allowedSites: [SitePermission] {
        allSitePermissions.filter { site in
            switch permissionKind {
            case .location: return site.locationAllowed
            case .camera: return site.cameraAllowed
            case .microphone: return site.microphoneAllowed
            case .notifications: return site.notificationsAllowed
            }
        }
    }

    private var blockedSites: [SitePermission] {
        allSitePermissions.filter { site in
            switch permissionKind {
            case .location: return !site.locationAllowed
            case .camera: return !site.cameraAllowed
            case .microphone: return !site.microphoneAllowed
            case .notifications: return !site.notificationsAllowed
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InlineBackButton(action: { dismiss() })

            Text(description)
                .foregroundStyle(.secondary)

            Group {
                Text("Customized behaviors").font(.headline)

                if !blockedSites.isEmpty {
                    Text(blockedText).font(.subheadline)
                    ForEach(blockedSites, id: \.host) { entry in
                        SiteRow(entry: entry, onRemove: { removeSite(entry) })
                    }
                }

                if !allowedSites.isEmpty {
                    Text(allowedText).font(.subheadline)
                    ForEach(allowedSites, id: \.host) { entry in
                        SiteRow(entry: entry, onRemove: { removeSite(entry) })
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add site (e.g. example.com)", text: $newHost)
                        .textFieldStyle(.roundedBorder)
                    Picker("Policy", selection: $newPolicyAllow) {
                        Text("Allow").tag(true)
                        Text("Block").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Button("Add") {
                        addSite()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func addSite() {
        let host = newHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        let existingSite = allSitePermissions.first {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }

        let site = existingSite ?? {
            let newSite = SitePermission(host: host)
            modelContext.insert(newSite)
            return newSite
        }()

        switch permissionKind {
        case .location: site.locationAllowed = newPolicyAllow
        case .camera: site.cameraAllowed = newPolicyAllow
        case .microphone: site.microphoneAllowed = newPolicyAllow
        case .notifications: site.notificationsAllowed = newPolicyAllow
        }

        try? modelContext.save()
        newHost = ""
        newPolicyAllow = true
    }

    private func removeSite(_ site: SitePermission) {
        modelContext.delete(site)
        try? modelContext.save()
    }
}

struct LocationPermissionView: View {
    var body: some View {
        DynamicPermissionView(
            permissionKind: .location,
            title: "Location",
            description: "Sites usually use your location for relevant features or info, like local news or nearby shops",
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
        DynamicPermissionView(
            permissionKind: .camera,
            title: "Camera",
            description: "Sites can ask to use your camera for video calls, photos, and other features",
            allowedText: "Allowed to use your camera",
            blockedText: "Not allowed to use your camera"
        )
    }
}

struct MicrophonePermissionView: View {
    var body: some View {
        DynamicPermissionView(
            permissionKind: .microphone,
            title: "Microphone",
            description: "Sites can ask to use your microphone for voice calls, recordings, and audio features",
            allowedText: "Allowed to use your microphone",
            blockedText: "Not allowed to use your microphone"
        )
    }
}

struct NotificationsPermissionView: View {
    var body: some View {
        DynamicPermissionView(
            permissionKind: .notifications,
            title: "Notifications",
            description: "Sites can ask to send you notifications for updates, messages, and alerts",
            allowedText: "Allowed to send notifications",
            blockedText: "Not allowed to send notifications"
        )
    }
}

struct EmbeddedContentPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Sites can ask to use information they've saved about you").foregroundStyle(.secondary)
            Text("No additional settings available yet.").foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct AdditionalPermissionListView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text(title).foregroundStyle(.secondary)
            Text("No additional settings available yet.").foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
