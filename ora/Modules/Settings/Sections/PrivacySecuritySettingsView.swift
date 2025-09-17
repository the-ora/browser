import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("Block third-party trackers", isOn: $settings.blockThirdPartyTrackers)
                Toggle("Block fingerprinting", isOn: $settings.blockFingerprinting)
                Toggle("Ad Blocking", isOn: $settings.adBlocking)
            }

            Section {
                Picker("Cookies", selection: $settings.cookiesPolicy) {
                    ForEach(CookiesPolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.top, -20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
