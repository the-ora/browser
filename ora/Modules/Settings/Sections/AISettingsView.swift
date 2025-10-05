import SwiftUI

struct AISettingsView: View {
    @Environment(\.theme) var theme
    @StateObject private var providerManager = AIProviderManager.shared
    @State private var openAIAPIKey: String = ""
    @State private var showAPIKeyField = false
    @State private var isAPIKeyVisible = false

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Integration")
                            .font(.headline)

                        Text("Configure AI providers to enable chat functionality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    // Provider Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider Status")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(providerManager.providers, id: \.name) { provider in
                            providerStatusRow(provider)
                        }
                    }

                    // OpenAI Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                if isAPIKeyVisible {
                                    TextField("Enter your API key...", text: $openAIAPIKey)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    SecureField("Enter your API key...", text: $openAIAPIKey)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(.body, design: .monospaced))
                                }

                                Button(action: { isAPIKeyVisible.toggle() }) {
                                    Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: saveOpenAIKey) {
                                    Text("Save")
                                }
                                .disabled(openAIAPIKey.isEmpty)

                                if KeychainService.shared.hasOpenAIKey() {
                                    Button(action: clearOpenAIKey) {
                                        Text("Remove")
                                    }
                                    .foregroundColor(.red)
                                }
                            }

                            Text("Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Usage Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About API Usage")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Your API keys are stored securely in macOS Keychain")
                            Text("• Keys are encrypted and never sent to our servers")
                            Text("• API requests are made directly from your browser to the provider")
                            Text("• You will be charged by the provider based on your usage")
                            Text("• Remove your API key anytime to disable AI features")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            loadAPIKeys()
        }
    }

    private func providerStatusRow(_ provider: AIProvider) -> some View {
        HStack {
            Image(systemName: provider.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(provider.isConfigured ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.subheadline)

                Text(provider.isConfigured ? "Configured" : "Requires API key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if provider.isConfigured {
                    Text("Models: " + provider.models.map(\.displayName).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if provider.isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
        }
        .padding(8)
        .background(
            provider.isConfigured ? Color.green.opacity(0.1) : Color.orange.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private func loadAPIKeys() {
        openAIAPIKey = KeychainService.shared.getOpenAIKey() ?? ""
    }

    private func saveOpenAIKey() {
        let success = KeychainService.shared.storeOpenAIKey(openAIAPIKey)

        if success {
            providerManager.refreshProviders()
            // Show success feedback
            NSSound(named: NSSound.Name("Glass"))?.play()
        } else {
            // Show error feedback
            NSSound.beep()
            print("Failed to save API key to keychain")
        }
    }

    private func clearOpenAIKey() {
        let success = KeychainService.shared.deleteOpenAIKey()

        if success {
            openAIAPIKey = ""
            providerManager.refreshProviders()
            NSSound(named: NSSound.Name("Glass"))?.play()
        } else {
            NSSound.beep()
            print("Failed to remove API key from keychain")
        }
    }
}
