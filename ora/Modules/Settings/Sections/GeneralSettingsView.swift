import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var updateService: UpdateService
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.theme) var theme

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    Image("banner-settings")
                        .resizable()
                        .frame(width: 576, height: 60)

                    HStack {
                        HStack {
                            Image("ora-logo-plain")
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("Ora Browser")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(getAppVersion())
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }.padding(.horizontal, 12)
                }
                .cornerRadius(12)

                HStack {
                    Text("Born for your Mac.")
                    Spacer()
                    Button("Set Ora as default") {
                        openDefaultBrowserSettings()
                    }
                    .background(theme.foreground)
                    .foregroundStyle(theme.background)
                    .clipShape(ConditionallyConcentricRectangle(cornerRadius: 6))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(theme.mutedSidebarBackground)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    AppearanceSelector(selection: $appearanceManager.appearance)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(
                                "Automatically check for updates",
                                isOn: $settings.autoUpdateEnabled
                            )

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
                                        .foregroundColor(
                                            updateService.updateAvailable
                                                ? .green : .secondary
                                        )
                                }

                                // Show last check time
                                if let lastCheck = updateService.lastCheckDate {
                                    Text(
                                        "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))"
                                    )
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func openDefaultBrowserSettings() {
        guard
            let url = URL(
                string:
                "x-apple.systempreferences:com.apple.preference.general?DefaultWebBrowser"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func getAppVersion() -> String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? "Unknown"
        let build =
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                ?? "Unknown"
        return "v\(version) (\(build))"
    }
}
