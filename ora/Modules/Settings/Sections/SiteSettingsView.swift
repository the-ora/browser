import SwiftUI

struct SiteSettingsView: View {
    @Environment(\.dismiss) private var dismiss
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

                    DisclosureGroup {
                        VStack(spacing: 0) {
                            PermissionRow(
                                title: "Background sync",
                                subtitle: "Recently closed sites can finish sending and receiving data",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Background sync")
                            }
                            PermissionRow(
                                title: "Motion sensors",
                                subtitle: "Sites can use motion sensors",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Motion sensors")
                            }
                            PermissionRow(
                                title: "Automatic downloads",
                                subtitle: "Sites can ask to automatically download multiple files",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Automatic downloads")
                            }
                            PermissionRow(
                                title: "Protocol handlers",
                                subtitle: "Sites can ask to handle protocols",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Protocol handlers")
                            }
                            PermissionRow(
                                title: "MIDI device control & reprogram",
                                subtitle: "Sites can ask to control and reprogram your MIDI devices",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "MIDI device control & reprogram")
                            }
                            PermissionRow(
                                title: "USB devices",
                                subtitle: "Sites can ask to connect to USB devices",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "USB devices")
                            }
                            PermissionRow(
                                title: "Serial ports",
                                subtitle: "Sites can ask to connect to serial ports",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Serial ports")
                            }
                            PermissionRow(
                                title: "File editing",
                                subtitle: "Sites can ask to edit files and folders on your device",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "File editing")
                            }
                            PermissionRow(
                                title: "HID devices",
                                subtitle: "Ask when a site wants to access HID devices",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "HID devices")
                            }
                            PermissionRow(
                                title: "Clipboard",
                                subtitle: "Sites can ask to see text and images on your clipboard",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Clipboard")
                            }
                            PermissionRow(
                                title: "Payment handlers",
                                subtitle: "Sites can install payment handlers",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Payment handlers")
                            }
                            PermissionRow(
                                title: "Augmented reality",
                                subtitle: "Ask when a site wants to create a 3D map of your surroundings or track camera position",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Augmented reality")
                            }
                            PermissionRow(
                                title: "Virtual reality",
                                subtitle: "Sites can ask to use virtual reality devices and data",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Virtual reality")
                            }
                            PermissionRow(
                                title: "Your device use",
                                subtitle: "Sites can ask to know when you're actively using your device",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Your device use")
                            }
                            PermissionRow(
                                title: "Window management",
                                subtitle: "Sites can ask to manage windows on all your displays",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Window management")
                            }
                            PermissionRow(
                                title: "Fonts",
                                subtitle: "Sites can ask to use fonts installed on your device",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Fonts")
                            }
                            PermissionRow(
                                title: "Automatic picture-in-picture",
                                subtitle: "Sites can enter picture-in-picture automatically",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Automatic picture-in-picture")
                            }
                            PermissionRow(
                                title: "Scrolling and zooming shared tabs",
                                subtitle: "Sites can ask to scroll and zoom shared tabs",
                                systemImage: "gear"
                            ) {
                                AdditionalPermissionListView(title: "Scrolling and zooming shared tabs")
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Additional permissions")
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationTitle("Site settings")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineBackButton(action: { dismiss() })
            Text("Sites can ask for your location").foregroundStyle(.secondary)
            PerSiteToggleList(keyPath: \._Location)
        }
        .navigationTitle("Location")
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
        .navigationTitle("Camera")
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
        .navigationTitle("Microphone")
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
        .navigationTitle("Notifications")
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
        .navigationTitle("Embedded content")
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
        .navigationTitle(title)
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
