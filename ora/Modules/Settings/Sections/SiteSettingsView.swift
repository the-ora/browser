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

private struct PerSiteToggleList: View {
    @ObservedObject var settings = SettingsStore.shared
    let keyPath: WritableKeyPath<SitePermissionSettings, Bool>

    var body: some View {
        List(Array(settings.sitePermissions.values).sorted(by: { $0.host < $1.host })) { item in
            Toggle(isOn: Binding(
                get: { item[keyPath: keyPath] },
                set: { newValue in
                    var updated = item
                    updated[keyPath: keyPath] = newValue
                    settings.upsertSitePermission(updated)
                }
            )) {
                Text(item.host)
            }
            .toggleStyle(.switch)
            .contextMenu {
                Button(role: .destructive) {
                    settings.removeSitePermission(host: item.host)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .listStyle(.inset)
    }
}

struct LocationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PermissionSettingsStore.shared
    @State private var newHost: String = ""
    @State private var newPolicyAllow: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InlineBackButton(action: { dismiss() })

            Text("Sites usually use your location for relevant features or info, like local news or nearby shops")
                .foregroundStyle(.secondary)

            Group {
                Text("Customized behaviors").font(.headline)

                let blocked = store.notAllowedSites(for: .location)
                let allowed = store.allowedSites(for: .location)

                if !blocked.isEmpty {
                    Text("Not allowed to see your location").font(.subheadline)
                    ForEach(blocked, id: \.host) { entry in
                        SiteRow(entry: entry, onRemove: { store.removeSite(host: entry.host) })
                    }
                }

                if !allowed.isEmpty {
                    Text("Allowed to see your location").font(.subheadline)
                    ForEach(allowed, id: \.host) { entry in
                        SiteRow(entry: entry, onRemove: { store.removeSite(host: entry.host) })
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
                        let host = newHost.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !host.isEmpty else { return }
                        store.addOrUpdateSite(host: host, allow: newPolicyAllow, for: .location)
                        newHost = ""
                        newPolicyAllow = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Sites can ask to use your camera").foregroundStyle(.secondary)
            PerSiteToggleList(keyPath: \._Camera)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct MicrophonePermissionView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Sites can ask to use your microphone").foregroundStyle(.secondary)
            PerSiteToggleList(keyPath: \._Microphone)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct NotificationsPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Collapse unwanted requests (recommended)").foregroundStyle(.secondary)
            PerSiteToggleList(keyPath: \._Notifications)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct EmbeddedContentPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Sites can ask to use information they've saved about you").foregroundStyle(.secondary)
            // Placeholder list reused for now
            PerSiteToggleList(keyPath: \._Notifications)
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

// MARK: - KeyPath helpers to access specific fields on SitePermissionSettings

private extension SitePermissionSettings {
    var _Location: Bool { get { location } set { location = newValue } }
    var _Camera: Bool { get { camera } set { camera = newValue } }
    var _Microphone: Bool { get { microphone } set { microphone = newValue } }
    var _Notifications: Bool { get { notifications } set { notifications = newValue } }
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
