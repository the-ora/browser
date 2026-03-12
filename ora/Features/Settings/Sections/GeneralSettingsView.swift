import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var updateService: UpdateService
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var defaultBrowserManager = DefaultBrowserManager.shared

    var body: some View {
        SettingsSection {
            SettingsCard {
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

            if !defaultBrowserManager.isDefault {
                SettingsCard {
                    HStack {
                        Text("Born for your Mac. Make Ora your default browser.")
                        Spacer()
                        Button("Set as Default") { DefaultBrowserManager.requestSetAsDefault() }
                    }
                }
            }

            AppearanceSelector(selection: $appearanceManager.appearance)

            SettingsCard(header: "Tab Management") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Suspend inactive tabs after:")
                        Spacer()
                        Picker("", selection: $settings.tabAliveTimeout) {
                            Text("1 hour").tag(TimeInterval(60 * 60))
                            Text("6 hours").tag(TimeInterval(6 * 60 * 60))
                            Text("12 hours").tag(TimeInterval(12 * 60 * 60))
                            Text("1 day").tag(TimeInterval(24 * 60 * 60))
                            Text("2 days").tag(TimeInterval(2 * 24 * 60 * 60))
                            Text("Never").tag(TimeInterval(365 * 24 * 60 * 60))
                        }
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Remove tabs after:")
                        Spacer()
                        Picker("", selection: $settings.tabRemovalTimeout) {
                            Text("1 hour").tag(TimeInterval(60 * 60))
                            Text("6 hours").tag(TimeInterval(6 * 60 * 60))
                            Text("12 hours").tag(TimeInterval(12 * 60 * 60))
                            Text("1 day").tag(TimeInterval(24 * 60 * 60))
                            Text("2 days").tag(TimeInterval(2 * 24 * 60 * 60))
                            Text("Never").tag(TimeInterval(365 * 24 * 60 * 60))
                        }
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Max recent tabs:")
                        Spacer()
                        Picker("", selection: $settings.maxRecentTabs) {
                            ForEach(1 ... 10, id: \.self) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .frame(width: 80)
                    }
                }

                Toggle("Auto Picture-in-Picture on tab switch", isOn: $settings.autoPiPEnabled)
            }

            SettingsCard(header: "Updates") {
                Toggle("Auto-check for updates", isOn: $settings.autoUpdateEnabled)

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

                    if let lastCheck = updateService.lastCheckDate {
                        Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version) (\(build))"
    }
}
