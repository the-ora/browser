import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var updateService: UpdateService
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.theme) var theme

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 16) {
                    // App Version Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ora Browser")
                                .font(.headline)
                            Spacer()
                            Text(getAppVersion())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Fast, secure, and beautiful browser built for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    HStack {
                        Text("Born for your Mac. Make Ora your default browser.")
                        Spacer()
                        Button("Set Ora as default") { openDefaultBrowserSettings() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    AppearanceSelector(selection: $appearanceManager.appearance)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates")
                            .font(.headline)

                        Toggle("Automatically check for updates", isOn: $settings.autoUpdateEnabled)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Check for Updates") {
                                    updateService.checkForUpdates()
                                }

                                if updateService.isCheckingForUpdates {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 16, height: 16)
                                }

                                if updateService.updateAvailable {
                                    Text("Update available!")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }

                            if let result = updateService.lastCheckResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(updateService.updateAvailable ? .green : .secondary)
                            }

                            // Show current app version
                            if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                Text("Current version: \(appVersion)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // Show last check time
                            if let lastCheck = updateService.lastCheckDate {
                                Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func openDefaultBrowserSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.general?DefaultWebBrowser"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version) (\(build))"
    }
}
