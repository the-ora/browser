import AppKit
import SwiftUI

@MainActor
func openPasswordsWindow() {
    PasswordsWindowController.shared.show()
}

@MainActor
private final class PasswordsWindowController: NSObject, NSWindowDelegate {
    static let shared = PasswordsWindowController()

    private var windowController: NSWindowController?

    func show() {
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(
            rootView: PasswordsWindowView()
                .withTheme()
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Passwords"
        window.minSize = CGSize(width: 960, height: 480)
        window.center()
        window.delegate = self
        window.contentViewController = hostingController
        window.setFrameAutosaveName("PasswordsWindow")

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === windowController?.window
        else {
            return
        }

        windowController = nil
    }
}

private struct PasswordsWindowView: View {
    @Environment(\.theme) private var theme
    @StateObject private var passwordManager = PasswordManagerService.shared

    @State private var searchText = ""
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var revealedPasswordIDs: [String: String] = [:]
    @State private var pendingDelete: SavedPasswordSummary?

    private var filteredEntries: [SavedPasswordSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return passwordManager.entries }

        return passwordManager.entries.filter { entry in
            entry.host.localizedCaseInsensitiveContains(query)
                || entry.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header

                if isUnlocked {
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
            .padding(20)
        }
        .frame(minWidth: 960, minHeight: 480)
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved Passwords")
                    .font(.title2.weight(.semibold))
                Text("\(passwordManager.entries.count) item\(passwordManager.entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                Button("Lock") {
                    lockVault()
                }
            }
        }
    }

    private var lockedVaultState: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.75))

                if passwordManager.canUseBiometricAuthentication() {
                    Button {
                        unlockVault()
                    } label: {
                        Image(systemName: "touchid")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 38, height: 38)
                            .background(Color(.windowBackgroundColor).opacity(0.92))
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

                Text("Authenticate to view saved passwords.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                unlockVault()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: passwordManager.canUseBiometricAuthentication() ? "touchid" : "lock.open")
                    Text(isAuthenticating ? "Unlocking..." : "Unlock Passwords")
                }
            }
            .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity, alignment: .center)
    }

    private var passwordsTable: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                passwordTableHeader

                Divider()
                    .overlay(Color(.separatorColor).opacity(0.7))

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries, id: \.id) { entry in
                            passwordTableRow(entry)

                            if entry.id != filteredEntries.last?.id {
                                Divider()
                                    .overlay(Color(.separatorColor).opacity(0.45))
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 800)
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separatorColor).opacity(0.55), lineWidth: 1)
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
        .background(Color(.controlBackgroundColor).opacity(0.3))
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
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .center)
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
