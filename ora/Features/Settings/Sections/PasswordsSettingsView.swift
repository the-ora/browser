import SwiftData
import SwiftUI

struct PasswordsSettingsView: View {
    @Query(sort: \TabContainer.lastAccessedAt, order: .reverse) var containers: [TabContainer]

    @StateObject private var settings = SettingsStore.shared
    @StateObject private var passwordManager = PasswordManagerService.shared
    private let providers = PasswordManagerProviderRegistry.shared

    @State private var searchText = ""
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var selectedContainerId: UUID?
    @State private var revealedPasswordIDs: [String: String] = [:]
    @State private var pendingDelete: SavedPasswordSummary?

    private var selectedProvider: PasswordManagerProviderDescriptor {
        providers.descriptor(for: settings.passwordManagerProvider)
    }

    private var selectedContainer: TabContainer? {
        containers.first { $0.id == selectedContainerId } ?? containers.first
    }

    private var visibleEntries: [SavedPasswordSummary] {
        passwordManager.entries(for: selectedContainer?.id)
    }

    private var filteredEntries: [SavedPasswordSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return visibleEntries }

        return visibleEntries.filter { entry in
            entry.host.localizedCaseInsensitiveContains(query)
                || entry.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            passwordsOverview
            vaultSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedContainerId == nil {
                selectedContainerId = containers.first?.id
            }
        }
        .onChange(of: containers.map(\.id)) { _, containerIDs in
            guard let selectedContainerId else {
                self.selectedContainerId = containerIDs.first
                return
            }

            if !containerIDs.contains(selectedContainerId) {
                self.selectedContainerId = containerIDs.first
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
        SettingsCard {
            HStack(alignment: .top) {
                Text("Password manager")
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Picker("", selection: $settings.passwordManagerProvider) {
                        ForEach(providers.providers) { provider in
                            Text(provider.title).tag(provider.kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()

                    Text(selectedProvider.summary)
                        .font(.caption)
                        .foregroundStyle(selectedProvider.isAvailable ? Color.secondary : .orange)
                }
            }

            Toggle("Enable password manager", isOn: $settings.passwordsEnabled)
            Toggle("Autofill on login forms", isOn: $settings.passwordAutofillEnabled)
                .disabled(!settings.passwordsEnabled)
            Toggle("Auto-submit after autofill", isOn: $settings.passwordAutofillSubmitEnabled)
                .disabled(
                    !settings.passwordsEnabled
                        || !settings.passwordAutofillEnabled
                        || !selectedProvider.usesBuiltInOverlay
                )
            Toggle("Prompt to save passwords", isOn: $settings.passwordSavePromptsEnabled)
                .disabled(!settings.passwordsEnabled || !selectedProvider.usesBuiltInVault)

            if !selectedProvider.isAvailable {
                Text("\(selectedProvider.title) is not yet integrated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var vaultSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedProvider.usesBuiltInVault ? "Saved Credentials" : selectedProvider.title)
                            .font(.headline)
                        if selectedProvider.usesBuiltInVault, isUnlocked {
                            Text("\(visibleEntries.count) item\(visibleEntries.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if selectedProvider.usesBuiltInVault, isUnlocked {
                        Button("Lock") {
                            lockVault()
                        }
                    }
                }

                if !selectedProvider.usesBuiltInVault {
                    emptyState(message: "\(selectedProvider.title) integration coming soon.")
                } else if containers.isEmpty {
                    emptyState(message: "Create a space to start storing passwords.")
                } else if isUnlocked {
                    spacePickerRow

                    TextField("Search saved passwords", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    if filteredEntries.isEmpty {
                        emptyState(message: searchText
                            .isEmpty ? "No saved passwords yet." : "No saved passwords match that search.")
                    } else {
                        passwordsTable
                    }
                } else {
                    lockedVaultState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var spacePickerRow: some View {
        HStack {
            Text("Space")
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: { selectedContainerId ?? containers.first?.id },
                    set: { selectedContainerId = $0 }
                )
            ) {
                ForEach(containers) { container in
                    Text(containerLabel(for: container)).tag(Optional(container.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 150, alignment: .trailing)
        }
    }

    private var lockedVaultState: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.75))

                if passwordManager.canUseBiometricAuthentication() {
                    Image(systemName: "touchid")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color(.windowBackgroundColor).opacity(0.92))
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 8) {
                Text("Passwords Are Locked")
                    .font(.title3.weight(.semibold))

                Text("Authenticate to view saved passwords.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            OraButton(
                label: isAuthenticating ? "Unlocking..." : "Unlock Passwords",
                variant: .outline,
                isDisabled: isAuthenticating,
                leadingIcon: passwordManager.canUseBiometricAuthentication() ? "touchid" : "lock.open"
            ) {
                unlockVault()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
    }

    private var passwordsTable: some View {
        GeometryReader { geometry in
            let contentWidth = max(minimumTableContentWidth, geometry.size.width)
            let actionsColumnWidth = max(52, contentWidth - 784)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    passwordTableHeader(actionsColumnWidth: actionsColumnWidth)

                    Divider()
                        .overlay(Color(.separatorColor).opacity(0.7))

                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredEntries, id: \.id) { entry in
                                passwordTableRow(entry, actionsColumnWidth: actionsColumnWidth)

                                if entry.id != filteredEntries.last?.id {
                                    Divider()
                                        .overlay(Color(.separatorColor).opacity(0.45))
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
            }
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separatorColor).opacity(0.55), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    }

    private var minimumTableContentWidth: CGFloat {
        836
    }

    private var tableLeadingInset: CGFloat {
        10
    }

    private var tableTrailingInset: CGFloat {
        14
    }

    private func passwordTableHeader(actionsColumnWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            tableHeaderCell("Site", width: 260, alignment: .leading)
            tableHeaderCell("Username", width: 220, alignment: .leading)
            tableHeaderCell("Password", width: 240, alignment: .leading)
            tableHeaderCell("Actions", width: actionsColumnWidth, alignment: .leading)
        }
        .padding(.leading, tableLeadingInset)
        .padding(.trailing, tableTrailingInset)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }

    private func passwordTableRow(_ entry: SavedPasswordSummary, actionsColumnWidth: CGFloat) -> some View {
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

            HStack(spacing: 6) {
                Text(entry.displayUsername)
                    .font(.subheadline)
                    .foregroundStyle(entry.username.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                copyActionButton(help: "Copy username") {
                    passwordManager.copyToPasteboard(entry.username)
                }
            }
            .frame(width: 220, alignment: .leading)

            HStack(spacing: 6) {
                Text(revealedPasswordIDs[entry.id] ?? "••••••••••••")
                    .font(.system(.subheadline, design: .monospaced))
                    .lineLimit(1)

                Button {
                    toggleReveal(entry)
                } label: {
                    Image(systemName: revealedPasswordIDs[entry.id] == nil ? "eye" : "eye.slash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help(revealedPasswordIDs[entry.id] == nil ? "Reveal password" : "Hide password")

                copyActionButton(help: "Copy password") {
                    copyPassword(entry)
                }
            }
            .frame(width: 240, alignment: .leading)

            HStack {
                Button(role: .destructive) {
                    pendingDelete = entry
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Delete saved password")
            }
            .frame(width: actionsColumnWidth, alignment: .leading)
        }
        .padding(.leading, tableLeadingInset)
        .padding(.trailing, tableTrailingInset)
        .padding(.vertical, 12)
    }

    private func tableHeaderCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
    }

    private func copyActionButton(help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OraIcons(
                icon: .copy,
                size: .custom(14),
                color: .secondary
            )
        }
        .buttonStyle(.plain)
        .help(help)
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

    private func containerLabel(for container: TabContainer) -> String {
        "\(container.emoji) \(container.name)"
    }
}
