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

    // Access the shared permission store
    private var permissionStore: PermissionSettingsStore {
        guard let store = PermissionSettingsStore.shared else {
            fatalError("PermissionSettingsStore.shared is not initialized")
        }
        return store
    }

    private var allowedSites: [SitePermission] {
        guard let permissionKind else { return [] }

        let filtered = allSitePermissions.filter { site in
            switch permissionKind {
            case .camera: return site.cameraConfigured && site.cameraAllowed
            case .microphone: return site.microphoneConfigured && site.microphoneAllowed
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
            case .camera: return site.cameraConfigured && !site.cameraAllowed
            case .microphone: return site.microphoneConfigured && !site.microphoneAllowed
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
        // Use the permission store to properly reset the site's permissions
        permissionStore.removeSite(host: site.host)

        // Refresh the view by forcing a model context save
        try? modelContext.save()
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
