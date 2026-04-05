import SwiftUI

struct PrivacySecuritySettingsView: View {
    var body: some View {
        SettingsSection {
            SettingsCard(header: "Coming Later") {
                Text(
                    "Space-specific privacy controls now live in Spaces. This section stays disabled until we add broader browser-wide privacy tools here."
                )
                .foregroundStyle(.secondary)
            }
        }
        .disabled(true)
    }
}
