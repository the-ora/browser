import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("Block third-party trackers", isOn: $settings.blockThirdPartyTrackers).disabled(true)
                Toggle("Block fingerprinting", isOn: $settings.blockFingerprinting).disabled(true)
                Toggle("Ad Blocking", isOn: $settings.adBlocking).disabled(true)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            Section {
                Picker("Cookies", selection: $settings.cookiesPolicy) {
                    ForEach(CookiesPolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
                .pickerStyle(.menu)
                .disabled(true)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.top, -20)
    }
}
