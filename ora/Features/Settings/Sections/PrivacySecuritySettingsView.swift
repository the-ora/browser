import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Section {
                            Text("Tracking Prevention").foregroundStyle(.secondary)
                            Toggle("Block third-party trackers", isOn: $settings.blockThirdPartyTrackers)
                            Toggle("Block fingerprinting", isOn: $settings.blockFingerprinting)
                            Toggle("Ad Blocking", isOn: $settings.adBlocking)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Section {
                            Text("Cookies").foregroundStyle(.secondary)
                            Picker("", selection: $settings.cookiesPolicy) {
                                ForEach(CookiesPolicy.allCases) { policy in
                                    Text(policy.rawValue).tag(policy)
                                }
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                }
            }
        }
    }
}
