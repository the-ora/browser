import AppKit
import SwiftData
import SwiftUI
import WebKit

// MARK: - Extensions Popup View

struct ExtensionsPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var tabManager: TabManager

    @State private var cameraPermission: PermissionState = .ask
    @State private var microphonePermission: PermissionState = .ask

    enum PermissionState: String, CaseIterable {
        case ask = "Ask"
        case allow = "Allow"
        case block = "Block"

        var next: PermissionState {
            switch self {
            case .ask: return .allow
            case .allow: return .block
            case .block: return .allow  // Don't go back to .ask
            }
        }
    }

    private var currentHost: String {
        return tabManager.activeTab?.url.host ?? "example.com"
    }

    private func togglePermission(_ kind: PermissionKind, currentState: Binding<PermissionState>) {
        let newState = currentState.wrappedValue.next
        currentState.wrappedValue = newState
        let isAllowed = newState == .allow

        // Update SwiftData
        updateSitePermission(for: kind, allow: isAllowed)

        // Notify the web view of the permission change
        if let tab = tabManager.activeTab {
            // Get the current URL and host
            let currentURL = tab.url
            let currentHost = currentURL.host ?? ""

            // Force the web view to re-evaluate permissions by temporarily changing the URL
            // This is a workaround to trigger a permission re-evaluation without a full page reload
            if currentURL.absoluteString.hasPrefix("http") {
                // Create a temporary URL with a different fragment to force a navigation
                var components = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)!
                let currentFragment = components.fragment ?? ""
                components.fragment = currentFragment.isEmpty ? "_" : ""

                if let tempURL = components.url {
                    // Store the original URL
                    let originalURL = currentURL

                    // Navigate to the temporary URL
                    tab.webView.load(URLRequest(url: tempURL))

                    // After a short delay, navigate back to the original URL
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        tab.webView.load(URLRequest(url: originalURL))
                    }
                }
            }
        }
    }

    private func updateSitePermission(for kind: PermissionKind, allow: Bool) {
        let host = currentHost

        // Find existing site permission or create new one
        let descriptor = FetchDescriptor<SitePermission>(
            predicate: #Predicate<SitePermission> { site in
                site.host.localizedStandardContains(host)
            }
        )

        let existingSite = try? modelContext.fetch(descriptor).first
        let site = existingSite ?? {
            let newSite = SitePermission(host: host)
            modelContext.insert(newSite)
            return newSite
        }()

        // Update the specific permission
        switch kind {
        case .camera:
            site.cameraAllowed = allow
            site.cameraConfigured = true
        case .microphone:
            site.microphoneAllowed = allow
            site.microphoneConfigured = true
        default:
            // All other permission types are not handled
            break
        }

        try? modelContext.save()
    }

    private func loadCurrentPermissions() {
        let host = currentHost

        let descriptor = FetchDescriptor<SitePermission>(
            predicate: #Predicate<SitePermission> { site in
                site.host.localizedStandardContains(host)
            }
        )

        if let site = try? modelContext.fetch(descriptor).first {
            cameraPermission = site.cameraConfigured ? (site.cameraAllowed ? .allow : .block) : .ask
            microphonePermission = site.microphoneConfigured ? (site.microphoneAllowed ? .allow : .block) : .ask
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Media Permissions
            VStack(alignment: .leading, spacing: 8) {
                Text("Media Permissions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Button(action: { togglePermission(.camera, currentState: $cameraPermission) }) {
                    PopupPermissionRow(icon: "camera", title: "Camera", status: cameraPermission.rawValue)
                }
                .buttonStyle(.plain)

                Button(action: { togglePermission(.microphone, currentState: $microphonePermission) }) {
                    PopupPermissionRow(icon: "mic", title: "Microphone", status: microphonePermission.rawValue)
                }
                .buttonStyle(.plain)

                SettingsLink {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)

                        Text("More settings")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    dismiss()
                }
            }

            .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            loadCurrentPermissions()
        }
    }
}

struct PopupActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ExtensionIcon: View {
    let index: Int

    private var iconName: String {
        let icons = [
            "doc.text",
            "globe",
            "circle.fill",
            "square.grid.2x2",
            "star.fill",
            "folder",
            "paintbrush",
            "plus.circle",
            "photo",
            "camera",
            "map",
            "gamecontroller",
            "music.note",
            "video",
            "textformat",
            "gear"
        ]
        return icons[index % icons.count]
    }

    private var iconColor: Color {
        let colors: [Color] = [.blue, .green, .red, .orange, .purple, .pink, .yellow, .gray]
        return colors[index % colors.count]
    }

    var body: some View {
        Button(action: {}) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct PopupPermissionRow: View {
    let icon: String
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(status == "Allow" ? .green : status == "Block" ? .red : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
