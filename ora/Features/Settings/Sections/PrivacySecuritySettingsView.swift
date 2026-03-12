import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        SettingsSection {
            SettingsCard(header: "Tracking Prevention") {
                Toggle("Block third-party trackers", isOn: $settings.blockThirdPartyTrackers)
                Toggle("Block fingerprinting", isOn: $settings.blockFingerprinting)
                Toggle("Ad Blocking", isOn: $settings.adBlocking)
            }

            SettingsCard(header: "Cookies") {
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
