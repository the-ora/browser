import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        SettingsSection {
            SettingsCard(header: "Tracking Prevention") {
                HStack {
                    Text("Soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.controlColor), in: Capsule())
                }

                Toggle("Block third-party trackers", isOn: .constant(false))
                Toggle("Block fingerprinting", isOn: .constant(false))
                Toggle("Ad Blocking", isOn: .constant(false))
            }
            .disabled(true)

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
