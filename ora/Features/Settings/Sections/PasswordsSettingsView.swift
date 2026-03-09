import SwiftUI

struct PasswordsSettingsView: View {
    @Environment(\.theme) private var theme
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var passwordManager = PasswordManagerService.shared
    private let providers = PasswordManagerProviderRegistry.shared

    @State private var searchText = ""
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var unlockedEntries: [SavedPasswordSummary] = []
    @State private var revealedPasswordIDs: [String: String] = [:]
    @State private var pendingDelete: SavedPasswordSummary?

    private var selectedProvider: PasswordManagerProviderDescriptor {
        providers.descriptor(for: settings.passwordManagerProvider)
    }

    private var filteredEntries: [SavedPasswordSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return unlockedEntries }

        return unlockedEntries.filter { entry in
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
                    syncUnlockedEntries()
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
                Toggle(
                    "Submit login forms after selecting a saved password",
                    isOn: $settings.passwordAutofillSubmitEnabled
                )
                .disabled(
                    !settings.passwordsEnabled
                        || !settings.passwordAutofillEnabled
                        || !selectedProvider.usesBuiltInOverlay
                )
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
                        if isUnlocked {
                            Text("\(unlockedEntries.count) item\(unlockedEntries.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Unlock to view saved passwords.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                        .isEmpty ? "No saved passwords yet." : "No saved passwords match that search."
                    )
                } else {
                    passwordsTable
                }
            } else {
                lockedVaultState
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.solidWindowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var lockedVaultState: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(theme.mutedForeground.opacity(0.75))

                if passwordManager.canUseBiometricAuthentication() {
                    Button {
                        unlockVault()
                    } label: {
                        Image(systemName: "touchid")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 38, height: 38)
                            .background(theme.background.opacity(0.92))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Use Touch ID to unlock")
                    .disabled(isAuthenticating)
                }
            }

            VStack(spacing: 8) {
                Text("Passwords Are Locked")
                    .font(.title3.weight(.semibold))

                Text(
                    "Use Touch ID or your Mac password to unlock passwords for \"\(passwordManager.currentAccountDisplayName())\"."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                OraButton(
                    label: isAuthenticating ? "Unlocking..." : "Unlock Passwords",
                    variant: .outline,
                    isDisabled: isAuthenticating,
                    leadingIcon: passwordManager.canUseBiometricAuthentication() ? "touchid" : "lock.open"
                ) {
                    unlockVault()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
    }

    private var passwordsTable: some View {
        VStack(spacing: 0) {
            passwordTableHeader

            Divider()
                .overlay(theme.border.opacity(0.7))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries, id: \.id) { entry in
                        passwordTableRow(entry)

                        if entry.id != filteredEntries.last?.id {
                            Divider()
                                .overlay(theme.border.opacity(0.45))
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(theme.background.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border.opacity(0.55), lineWidth: 1)
        }
    }

    private var passwordTableHeader: some View {
        HStack(spacing: 12) {
            tableHeaderCell("Site", width: 260, alignment: .leading)
            tableHeaderCell("Username", width: 220, alignment: .leading)
            tableHeaderCell("Password", width: 240, alignment: .leading)
            tableHeaderCell("Actions", width: 52, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.background.opacity(0.16))
    }

    private func passwordTableRow(_ entry: SavedPasswordSummary) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                SiteFaviconView(host: entry.host, size: 20, cornerRadius: 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.host)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let origin = entry.origin {
                        Text(origin)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 260, alignment: .leading)

            HStack(spacing: 8) {
                Text(entry.displayUsername)
                    .font(.subheadline)
                    .foregroundStyle(entry.username.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    passwordManager.copyToPasteboard(entry.username)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Copy username")
            }
            .frame(width: 220, alignment: .leading)

            HStack(spacing: 8) {
                Text(revealedPasswordIDs[entry.id] ?? "••••••••••••")
                    .font(.system(.subheadline, design: .monospaced))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    toggleReveal(entry)
                } label: {
                    Image(systemName: revealedPasswordIDs[entry.id] == nil ? "eye" : "eye.slash")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(revealedPasswordIDs[entry.id] == nil ? "Reveal password" : "Hide password")

                Button {
                    copyPassword(entry)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Copy password")
            }
            .frame(width: 240, alignment: .leading)

            HStack {
                Spacer()

                Button(role: .destructive) {
                    pendingDelete = entry
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Delete saved password")

                Spacer()
            }
            .frame(width: 52)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func tableHeaderCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
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
                    syncUnlockedEntries()
                }
            }
        }
    }

    private func lockVault() {
        isUnlocked = false
        isAuthenticating = false
        searchText = ""
        unlockedEntries.removeAll()
        revealedPasswordIDs.removeAll()
    }

    private func syncUnlockedEntries() {
        unlockedEntries = passwordManager.entries
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
