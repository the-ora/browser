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
                                title: "Clipboard",
                                subtitle: "Sites can ask to read your clipboard",
                                systemImage: "clipboard"
                            ) {
                                AdditionalPermissionListView(title: "Clipboard")
                            }
                            PermissionRow(
                                title: "Sensors",
                                subtitle: "Sites can ask to use sensors",
                                systemImage: "dot.radiowaves.left.right"
                            ) {
                                AdditionalPermissionListView(title: "Sensors")
                            }
                            PermissionRow(
                                title: "Popups and redirects",
                                subtitle: "Manage popups and redirects",
                                systemImage: "arrowshape.turn.up.right"
                            ) {
                                AdditionalPermissionListView(title: "Popups and redirects")
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
