import AppKit
import Foundation
import WebKit

enum PasswordFormAction: String, Codable {
    case login
    case createAccount
}

struct PasswordBridgeRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct PasswordBridgeFocusPayload: Codable, Equatable {
    let fieldID: String
    let hostname: String
    let action: PasswordFormAction
    let usernameFieldID: String?
    let passwordFieldIDs: [String]
    let rect: PasswordBridgeRect
}

struct PasswordBridgeSubmitPayload: Codable, Equatable {
    let hostname: String
    let username: String
    let password: String
    let action: PasswordFormAction
}

struct PasswordBridgeEvent: Codable, Equatable {
    let type: String
    let focus: PasswordBridgeFocusPayload?
    let submit: PasswordBridgeSubmitPayload?
    let fieldID: String?
    let rect: PasswordBridgeRect?
}

struct PasswordFillRequest: Codable {
    let usernameFieldID: String?
    let passwordFieldIDs: [String]
    let username: String?
    let password: String
    let highlightColor: String
}

struct PasswordAutofillOverlayState: Equatable {
    let focus: PasswordBridgeFocusPayload
    let matchingEntries: [SavedPasswordSummary]
    let generatedPassword: String?
}

final class PasswordAutofillCoordinator {
    weak var tab: Tab?

    private let passwordManager = PasswordManagerService.shared
    private let settings = SettingsStore.shared
    private let decoder = JSONDecoder()

    private var dismissWorkItem: DispatchWorkItem?

    init(tab: Tab) {
        self.tab = tab
    }

    func handleMessage(_ messageBody: String) {
        guard let data = messageBody.data(using: .utf8),
              let message = try? decoder.decode(PasswordBridgeEvent.self, from: data)
        else {
            return
        }

        switch message.type {
        case "focus":
            dismissWorkItem?.cancel()
            if let focus = message.focus {
                presentOverlay(for: focus)
            }
        case "blur":
            scheduleDismissOverlay()
        case "rect":
            if let fieldID = message.fieldID, let rect = message.rect {
                updateOverlayRect(for: fieldID, rect: rect)
            }
        case "submit":
            dismissOverlay()
            if let submit = message.submit {
                handleSubmit(submit)
            }
        default:
            break
        }
    }

    func dismissOverlay() {
        dismissWorkItem?.cancel()
        tab?.passwordOverlayState = nil
    }

    func autofill(_ entry: SavedPasswordSummary, for overlay: PasswordAutofillOverlayState) {
        guard let webView = tab?.webView,
              let password = try? passwordManager.revealPassword(for: entry)
        else {
            return
        }

        let request = PasswordFillRequest(
            usernameFieldID: overlay.focus.usernameFieldID,
            passwordFieldIDs: overlay.focus.passwordFieldIDs,
            username: entry.username.isEmpty ? nil : entry.username,
            password: password,
            highlightColor: "#E8F5E9"
        )

        evaluate(scriptMethod: "fillCredentials", payload: request, in: webView)
        passwordManager.markUsed(entry)
        dismissOverlay()
    }

    func fillGeneratedPassword(for overlay: PasswordAutofillOverlayState) {
        guard let webView = tab?.webView,
              let generatedPassword = overlay.generatedPassword
        else {
            return
        }

        let request = PasswordFillRequest(
            usernameFieldID: nil,
            passwordFieldIDs: overlay.focus.passwordFieldIDs,
            username: nil,
            password: generatedPassword,
            highlightColor: "#FFF4CC"
        )

        evaluate(scriptMethod: "fillCredentials", payload: request, in: webView)
        dismissOverlay()
    }

    func openPasswordsSettings() {
        UserDefaults.standard.set(SettingsTab.passwords.rawValue, forKey: SettingsContentView.selectedTabDefaultsKey)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        dismissOverlay()
    }

    private func presentOverlay(for focus: PasswordBridgeFocusPayload) {
        guard settings.passwordsEnabled,
              settings.passwordAutofillEnabled,
              tab?.isPrivate == false
        else {
            dismissOverlay()
            return
        }

        let normalizedHost = PasswordManagerService.normalizeHost(focus.hostname)
        let entries = passwordManager.matchingEntries(forHost: normalizedHost)
        let generatedPassword = focus.action == .createAccount ? passwordManager.generateStrongPassword() : nil

        guard !entries.isEmpty || generatedPassword != nil else {
            dismissOverlay()
            return
        }

        tab?.passwordOverlayState = PasswordAutofillOverlayState(
            focus: PasswordBridgeFocusPayload(
                fieldID: focus.fieldID,
                hostname: normalizedHost,
                action: focus.action,
                usernameFieldID: focus.usernameFieldID,
                passwordFieldIDs: focus.passwordFieldIDs,
                rect: focus.rect
            ),
            matchingEntries: entries,
            generatedPassword: generatedPassword
        )
    }

    private func updateOverlayRect(for fieldID: String, rect: PasswordBridgeRect) {
        guard let overlay = tab?.passwordOverlayState,
              overlay.focus.fieldID == fieldID
        else {
            return
        }

        tab?.passwordOverlayState = PasswordAutofillOverlayState(
            focus: PasswordBridgeFocusPayload(
                fieldID: overlay.focus.fieldID,
                hostname: overlay.focus.hostname,
                action: overlay.focus.action,
                usernameFieldID: overlay.focus.usernameFieldID,
                passwordFieldIDs: overlay.focus.passwordFieldIDs,
                rect: rect
            ),
            matchingEntries: overlay.matchingEntries,
            generatedPassword: overlay.generatedPassword
        )
    }

    private func handleSubmit(_ payload: PasswordBridgeSubmitPayload) {
        guard settings.passwordsEnabled,
              settings.passwordSavePromptsEnabled,
              tab?.isPrivate == false
        else {
            return
        }

        let normalizedHost = PasswordManagerService.normalizeHost(payload.hostname)
        let trimmedUsername = payload.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = payload.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard payload.action == .login || payload.action == .createAccount,
              !trimmedPassword.isEmpty
        else {
            return
        }

        let matchingEntry = passwordManager.entries.first {
            PasswordManagerService.normalizeHost($0.host) == normalizedHost && $0.username == trimmedUsername
        }

        if let matchingEntry,
           let storedPassword = try? passwordManager.revealPassword(for: matchingEntry),
           storedPassword == trimmedPassword
        {
            return
        }

        let saveTitle = matchingEntry == nil ? "Save Password" : "Update Password"
        let saveMessage = matchingEntry == nil
            ? "Save the password for \(trimmedUsername.isEmpty ? normalizedHost : trimmedUsername)?"
            : "Update the saved password for \(trimmedUsername.isEmpty ? normalizedHost : trimmedUsername)?"

        if let window = tab?.webView.window {
            let alert = NSAlert()
            alert.messageText = saveTitle
            alert.informativeText = saveMessage
            alert.addButton(withTitle: saveTitle)
            alert.addButton(withTitle: "Not Now")
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                try? self?.passwordManager.upsertCredential(
                    host: normalizedHost,
                    username: trimmedUsername,
                    password: trimmedPassword
                )
            }
            return
        }

        try? passwordManager.upsertCredential(
            host: normalizedHost,
            username: trimmedUsername,
            password: trimmedPassword
        )
    }

    private func scheduleDismissOverlay() {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.tab?.passwordOverlayState = nil
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func evaluate(scriptMethod: String, payload: some Encodable, in webView: WKWebView) {
        guard let data = try? JSONEncoder().encode(payload),
              let payloadString = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = """
        if (window.__oraPasswordManager && typeof window.__oraPasswordManager.\(scriptMethod) === 'function') {
            window.__oraPasswordManager.\(scriptMethod)(\(payloadString));
        }
        """
        webView.evaluateJavaScript(script)
    }
}
