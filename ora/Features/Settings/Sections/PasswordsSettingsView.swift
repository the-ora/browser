import SwiftUI

struct PasswordsSettingsView: View {
    @Environment(\.theme) private var theme
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var passwordManager = PasswordManagerService.shared
    private let providers = PasswordManagerProviderRegistry.shared

    @State private var searchText = ""
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var revealedPasswordIDs: [String: String] = [:]
    @State private var pendingDelete: SavedPasswordSummary?

    private var selectedProvider: PasswordManagerProviderDescriptor {
        providers.descriptor(for: settings.passwordManagerProvider)
    }

    private var filteredEntries: [SavedPasswordSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return passwordManager.entries }

        return passwordManager.entries.filter { entry in
            entry.host.localizedCaseInsensitiveContains(query)
                || entry.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        SettingsContainer(maxContentWidth: 860) {
            VStack(alignment: .leading, spacing: 20) {
                passwordsOverview
                vaultSection
            }
        }
        .onDisappear {
            lockVault()
        }
        .alert("Delete saved password?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    try? passwordManager.delete(pendingDelete)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            if let pendingDelete {
                Text("Remove the saved credential for \(pendingDelete.displayUsername) on \(pendingDelete.host)?")
            }
        }
    }

    private var passwordsOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Passwords")
                .font(.title2.weight(.semibold))

            Text(
                "Choose which password manager Ora should integrate with. Ora Passwords stores encrypted credentials in synchronizable Keychain items; external providers will bring their own vault and autofill surfaces."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Password manager", selection: $settings.passwordManagerProvider) {
                    ForEach(providers.providers) { provider in
                        Text(provider.title).tag(provider.kind)
                    }
                }
                .pickerStyle(.menu)

                Text(selectedProvider.summary)
                    .font(.caption)
                    .foregroundStyle(selectedProvider.isAvailable ? Color.secondary : .orange)

                Toggle("Enable password manager", isOn: $settings.passwordsEnabled)
                Toggle("Show autofill suggestions on login forms", isOn: $settings.passwordAutofillEnabled)
                    .disabled(!settings.passwordsEnabled)
                Toggle("Ask to save or update passwords after sign in", isOn: $settings.passwordSavePromptsEnabled)
                    .disabled(!settings.passwordsEnabled || !selectedProvider.usesBuiltInVault)
            }

            if !selectedProvider.isAvailable {
                Text(
                    "\(selectedProvider.title) is not integrated yet. Selecting it reserves the provider slot, but Ora will not show its built-in vault or save prompts for that provider."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.solidWindowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedProvider.usesBuiltInVault ? "Saved Credentials" : selectedProvider.title)
                        .font(.headline)
                    if selectedProvider.usesBuiltInVault {
                        Text("\(passwordManager.entries.count) item\(passwordManager.entries.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This provider will manage its own vault and autofill UI once integrated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if selectedProvider.usesBuiltInVault {
                    if isUnlocked {
                        Button("Lock") {
                            lockVault()
                        }
                    } else {
                        Button {
                            unlockVault()
                        } label: {
                            if isAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 72)
                            } else {
                                Text("Unlock")
                            }
                        }
                        .disabled(isAuthenticating)
                    }
                }
            }

            if !selectedProvider.usesBuiltInVault {
                emptyState(
                    message: "\(selectedProvider.title) will expose its own account picker, vault controls, and autofill overlay when the native integration is added."
                )
            } else if isUnlocked {
                TextField("Search saved passwords", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if filteredEntries.isEmpty {
                    emptyState(message: searchText
                        .isEmpty ? "No saved passwords yet." : "No saved passwords match that search.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEntries, id: \.id) { entry in
                                credentialRow(entry)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                emptyState(message: "Unlock to view, reveal, copy, and delete saved passwords.")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.solidWindowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func credentialRow(_ entry: SavedPasswordSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 12) {
                    SiteFaviconView(host: entry.host, size: 22, cornerRadius: 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.host)
                            .font(.headline)
                        Text(entry.displayUsername)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Copy Username") {
                    passwordManager.copyToPasteboard(entry.username)
                }
                .buttonStyle(.borderless)

                Button(revealedPasswordIDs[entry.id] == nil ? "Reveal" : "Hide") {
                    toggleReveal(entry)
                }
                .buttonStyle(.borderless)

                Button("Copy Password") {
                    copyPassword(entry)
                }
                .buttonStyle(.borderless)

                Button("Delete", role: .destructive) {
                    pendingDelete = entry
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 10) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(revealedPasswordIDs[entry.id] ?? "••••••••••••")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            HStack(spacing: 14) {
                metadataLabel("Updated", value: entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let lastUsedAt = entry.lastUsedAt {
                    metadataLabel("Last Used", value: lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metadataLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }

    private func emptyState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(.secondary)
            if let lastErrorMessage = passwordManager.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }

    private func unlockVault() {
        isAuthenticating = true
        Task {
            let authenticated = await passwordManager.authenticate(reason: "Unlock your saved passwords in Ora")
            await MainActor.run {
                isUnlocked = authenticated
                isAuthenticating = false
                if authenticated {
                    passwordManager.refresh()
                }
            }
        }
    }

    private func lockVault() {
        isUnlocked = false
        isAuthenticating = false
        searchText = ""
        revealedPasswordIDs.removeAll()
    }

    private func toggleReveal(_ entry: SavedPasswordSummary) {
        if revealedPasswordIDs[entry.id] != nil {
            revealedPasswordIDs[entry.id] = nil
            return
        }

        if let password = try? passwordManager.revealPassword(for: entry) {
            revealedPasswordIDs[entry.id] = password
        }
    }

    private func copyPassword(_ entry: SavedPasswordSummary) {
        if let password = try? passwordManager.revealPassword(for: entry) {
            passwordManager.copySensitiveToPasteboard(password)
        }
    }
}
