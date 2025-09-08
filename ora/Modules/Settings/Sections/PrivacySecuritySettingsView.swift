import SwiftUI

struct PrivacySecuritySettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
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

                        VStack(alignment: .leading, spacing: 12) {
                            Section {
                                NavigationLink {
                                    SiteSettingsView()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "gear")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Site settings")
                                            Text("Manage permissions by site")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
