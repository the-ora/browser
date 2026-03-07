import AppKit
import Foundation
import WebKit

enum PasswordFormAction: String, Codable {
    case login
    case createAccount
}

struct PasswordBridgeRect: Codable, Equatable {
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double

    enum CodingKeys: String, CodingKey {
        case originX = "x"
        case originY = "y"
        case width
        case height
    }

    var cgRect: CGRect {
        CGRect(x: originX, y: originY, width: width, height: height)
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

struct PasswordSavePromptDetails: Equatable {
    let title: String
    let message: String
    let confirmButtonTitle: String
    let neverButtonTitle: String
    let showsSecurityWarning: Bool
}

final class PasswordAutofillCoordinator {
    weak var tab: Tab?

    private let passwordManager = PasswordManagerService.shared
    private let providers = PasswordManagerProviderRegistry.shared
    private let settings = SettingsStore.shared
    private let decoder = JSONDecoder()

    private var dismissWorkItem: DispatchWorkItem?

    init(tab: Tab) {
        self.tab = tab
    }

    func handleMessage(_ messageBody: String, pageURL: URL?) {
        guard let data = messageBody.data(using: .utf8),
              let message = try? decoder.decode(PasswordBridgeEvent.self, from: data)
        else {
            return
        }

        switch message.type {
        case "focus":
            dismissWorkItem?.cancel()
            if let focus = message.focus {
                presentOverlay(for: focus, pageURL: pageURL)
            }
        case "blur":
            scheduleDismissOverlay()
        case "rect":
            if let fieldID = message.fieldID, let rect = message.rect {
                updateOverlayRect(for: fieldID, rect: rect)
            }
        case "submit":
            clearAutofillState()
            if let submit = message.submit {
                handleSubmit(submit, pageURL: pageURL)
            }
        default:
            break
        }
    }

    func dismissOverlay() {
        dismissWorkItem?.cancel()
        tab?.passwordOverlayState = nil
    }

    func clearAutofillState() {
        dismissWorkItem?.cancel()
        tab?.passwordOverlayState = nil
        tab?.passwordTriggerOverlayState = nil
    }

    func presentTriggerOverlay() {
        dismissWorkItem?.cancel()
        guard let overlay = tab?.passwordTriggerOverlayState else { return }
        tab?.passwordOverlayState = overlay
    }

    func autofill(_ entry: SavedPasswordSummary, for overlay: PasswordAutofillOverlayState) {
        Task { [weak self] in
            guard let self else { return }

            let authenticated = await self.passwordManager.authenticate(
                reason: "Autofill the saved password for \(entry.displayUsername) on \(entry.host)"
            )
            guard authenticated,
                  let password = try? self.passwordManager.revealPassword(for: entry)
            else {
                return
            }

            await MainActor.run {
                guard let webView = self.tab?.webView else { return }

                let request = PasswordFillRequest(
                    usernameFieldID: overlay.focus.usernameFieldID,
                    passwordFieldIDs: overlay.focus.passwordFieldIDs,
                    username: entry.username.isEmpty ? nil : entry.username,
                    password: password,
                    highlightColor: "#E8F5E9"
                )

                self.evaluate(scriptMethod: "fillCredentials", payload: request, in: webView)
                self.passwordManager.markUsed(entry)
                self.dismissOverlay()
            }
        }
    }

    func fillGeneratedPassword(for overlay: PasswordAutofillOverlayState) {
        guard let generatedPassword = overlay.generatedPassword else {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            let authenticated = await self.passwordManager.authenticate(
                reason: "Fill the suggested password for \(overlay.focus.hostname)"
            )
            guard authenticated else {
                return
            }

            await MainActor.run {
                guard let webView = self.tab?.webView else { return }

                let request = PasswordFillRequest(
                    usernameFieldID: nil,
                    passwordFieldIDs: overlay.focus.passwordFieldIDs,
                    username: nil,
                    password: generatedPassword,
                    highlightColor: "#FFF4CC"
                )

                self.evaluate(scriptMethod: "fillCredentials", payload: request, in: webView)
                self.dismissOverlay()
            }
        }
    }

    func openPasswordsSettings() {
        UserDefaults.standard.set(SettingsTab.passwords.rawValue, forKey: SettingsContentView.selectedTabDefaultsKey)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        dismissOverlay()
    }

    private func presentOverlay(for focus: PasswordBridgeFocusPayload, pageURL: URL?) {
        let provider = providers.descriptor(for: settings.passwordManagerProvider)
        guard settings.passwordsEnabled,
              settings.passwordAutofillEnabled,
              provider.usesBuiltInOverlay,
              tab?.isPrivate == false,
              let pageURL,
              let normalizedHost = PasswordManagerService.normalizedHost(from: pageURL)
        else {
            clearAutofillState()
            return
        }

        let entries = passwordManager.matchingEntries(for: pageURL)
        let generatedPassword = focus.action == .createAccount ? passwordManager.generateStrongPassword() : nil

        guard !entries.isEmpty || generatedPassword != nil else {
            clearAutofillState()
            return
        }

        let overlayState = PasswordAutofillOverlayState(
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

        tab?.passwordTriggerOverlayState = overlayState
        tab?.passwordOverlayState = overlayState
    }

    private func updateOverlayRect(for fieldID: String, rect: PasswordBridgeRect) {
        if let triggerOverlay = tab?.passwordTriggerOverlayState,
           triggerOverlay.focus.fieldID == fieldID
        {
            tab?.passwordTriggerOverlayState = overlayState(triggerOverlay, updatingRectTo: rect)
        }

        if let overlay = tab?.passwordOverlayState,
           overlay.focus.fieldID == fieldID
        {
            tab?.passwordOverlayState = overlayState(overlay, updatingRectTo: rect)
        }
    }

    private func handleSubmit(_ payload: PasswordBridgeSubmitPayload, pageURL: URL?) {
        let provider = providers.descriptor(for: settings.passwordManagerProvider)
        guard settings.passwordsEnabled,
              settings.passwordSavePromptsEnabled,
              provider.usesBuiltInVault,
              tab?.isPrivate == false,
              let pageURL,
              let normalizedHost = PasswordManagerService.normalizedHost(from: pageURL)
        else {
            return
        }

        guard settings.allowsPasswordSavePrompts(for: normalizedHost) else {
            return
        }

        let trimmedUsername = payload.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = payload.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard payload.action == .login || payload.action == .createAccount,
              !trimmedPassword.isEmpty
        else {
            return
        }

        let matchingEntry = passwordManager
            .matchingEntries(for: pageURL)
            .first { $0.username == trimmedUsername }

        if let matchingEntry,
           let storedPassword = try? passwordManager.revealPassword(for: matchingEntry),
           storedPassword == trimmedPassword
        {
            return
        }

        let prompt = Self.savePromptDetails(
            for: pageURL,
            username: trimmedUsername,
            normalizedHost: normalizedHost,
            isUpdate: matchingEntry != nil
        )

        let saveAction = {
            try? self.passwordManager.upsertCredential(
                for: pageURL,
                username: trimmedUsername,
                password: trimmedPassword
            )
        }

        if let window = tab?.webView.window {
            let alert = NSAlert()
            alert.alertStyle = prompt.showsSecurityWarning ? .warning : .informational
            alert.messageText = prompt.title
            alert.informativeText = prompt.message
            alert.addButton(withTitle: prompt.confirmButtonTitle)
            alert.addButton(withTitle: "Not Now")
            alert.addButton(withTitle: prompt.neverButtonTitle)
            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn:
                    saveAction()
                case .alertThirdButtonReturn:
                    self.settings.suppressPasswordSavePrompts(for: normalizedHost)
                default:
                    break
                }
            }
            return
        }

        let alert = NSAlert()
        alert.alertStyle = prompt.showsSecurityWarning ? .warning : .informational
        alert.messageText = prompt.title
        alert.informativeText = prompt.message
        alert.addButton(withTitle: prompt.confirmButtonTitle)
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: prompt.neverButtonTitle)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveAction()
        case .alertThirdButtonReturn:
            settings.suppressPasswordSavePrompts(for: normalizedHost)
        default:
            break
        }
    }

    private func scheduleDismissOverlay() {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.clearAutofillState()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func overlayState(
        _ overlay: PasswordAutofillOverlayState,
        updatingRectTo rect: PasswordBridgeRect
    ) -> PasswordAutofillOverlayState {
        PasswordAutofillOverlayState(
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

    static func savePromptDetails(
        for pageURL: URL,
        username: String,
        normalizedHost: String,
        isUpdate: Bool
    ) -> PasswordSavePromptDetails {
        let accountLabel = username.isEmpty ? normalizedHost : username
        let isInsecurePage = pageURL.scheme?.localizedCaseInsensitiveCompare("http") == .orderedSame

        if isInsecurePage {
            let actionTitle = isUpdate ? "Update Password on Insecure Page" : "Save Password on Insecure Page"
            let buttonTitle = isUpdate ? "Update Anyway" : "Save Anyway"
            let actionVerb = isUpdate ? "update" : "save"
            return PasswordSavePromptDetails(
                title: actionTitle,
                message: "This page uses an insecure connection (http://), so other people on the network may be able to read the password. Do you still want to \(actionVerb) the password for \(accountLabel)?",
                confirmButtonTitle: buttonTitle,
                neverButtonTitle: "Never on This Site",
                showsSecurityWarning: true
            )
        }

        let title = isUpdate ? "Update Password" : "Save Password"
        let message = isUpdate
            ? "Update the saved password for \(accountLabel)?"
            : "Save the password for \(accountLabel)?"

        return PasswordSavePromptDetails(
            title: title,
            message: message,
            confirmButtonTitle: title,
            neverButtonTitle: "Never on This Site",
            showsSecurityWarning: false
        )
    }
}
