import AppKit
import Foundation

enum PasswordFormAction: String, Codable {
    case login
    case createAccount
}

enum PasswordAutofillFieldKind: String, Codable {
    case email
    case password
    case username
}

enum PasswordAutofillKeyCommand: String, Codable {
    case moveUp
    case moveDown
    case activate
    case dismiss
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
    let fieldKind: PasswordAutofillFieldKind
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
    let keyCommand: PasswordAutofillKeyCommand?
    let fieldID: String?
    let rect: PasswordBridgeRect?
}

struct PasswordFillRequest: Codable {
    let usernameFieldID: String?
    let passwordFieldIDs: [String]
    let username: String?
    let password: String
    let highlightColor: String
    let submitAfterFill: Bool
}

enum PasswordAutofillSuggestion: Identifiable, Equatable {
    case generatedPassword(host: String, password: String)
    case savedCredential(SavedPasswordSummary)
    case email(PasswordEmailSuggestion)

    var id: String {
        switch self {
        case let .generatedPassword(_, password):
            return "generated-\(password)"
        case let .savedCredential(entry):
            return "saved-\(entry.id)"
        case let .email(suggestion):
            return "email-\(suggestion.id)"
        }
    }

    var host: String {
        switch self {
        case let .generatedPassword(host, _):
            return host
        case let .savedCredential(entry):
            return entry.host
        case let .email(suggestion):
            return suggestion.host
        }
    }
}

struct PasswordAutofillOverlayState: Equatable {
    let focus: PasswordBridgeFocusPayload
    let savedPasswordEntries: [SavedPasswordSummary]
    let emailSuggestions: [PasswordEmailSuggestion]
    let generatedPassword: String?
    let selectedSuggestionIndex: Int

    var suggestions: [PasswordAutofillSuggestion] {
        var items: [PasswordAutofillSuggestion] = []

        if let generatedPassword {
            items.append(.generatedPassword(host: focus.hostname, password: generatedPassword))
        }

        items.append(contentsOf: savedPasswordEntries.prefix(4).map(PasswordAutofillSuggestion.savedCredential))
        items.append(contentsOf: emailSuggestions.prefix(4).map(PasswordAutofillSuggestion.email))

        return items
    }
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
        case "keyCommand":
            if let command = message.keyCommand {
                handleKeyCommand(command)
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
        setOverlayKeyboardActive(false)
    }

    func clearAutofillState() {
        dismissWorkItem?.cancel()
        tab?.passwordOverlayState = nil
        tab?.passwordTriggerOverlayState = nil
        setOverlayKeyboardActive(false)
    }

    func presentTriggerOverlay() {
        dismissWorkItem?.cancel()
        guard let overlay = tab?.passwordTriggerOverlayState else { return }
        tab?.passwordOverlayState = overlay
        setOverlayKeyboardActive(true)
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
                let request = PasswordFillRequest(
                    usernameFieldID: overlay.focus.usernameFieldID,
                    passwordFieldIDs: overlay.focus.passwordFieldIDs,
                    username: entry.username.isEmpty ? nil : entry.username,
                    password: password,
                    highlightColor: "#E8F5E9",
                    submitAfterFill: overlay.focus.action == .login && self.settings.passwordAutofillSubmitEnabled
                )

                self.evaluate(scriptMethod: "fillCredentials", payload: request)
                self.passwordManager.markUsed(entry)
                self.dismissOverlay()
            }
        }
    }

    func fillGeneratedPassword(for overlay: PasswordAutofillOverlayState) {
        guard let generatedPassword = overlay.generatedPassword else {
            return
        }

        guard tab?.browserPage != nil else {
            return
        }

        let request = PasswordFillRequest(
            usernameFieldID: nil,
            passwordFieldIDs: overlay.focus.passwordFieldIDs,
            username: nil,
            password: generatedPassword,
            highlightColor: "#FFF4CC",
            submitAfterFill: false
        )

        evaluate(scriptMethod: "fillCredentials", payload: request)
        dismissOverlay()
    }

    func fillEmailSuggestion(_ suggestion: PasswordEmailSuggestion, for overlay: PasswordAutofillOverlayState) {
        guard overlay.focus.fieldKind == .email else {
            return
        }

        guard tab?.browserPage != nil else {
            return
        }

        let request = PasswordFillRequest(
            usernameFieldID: overlay.focus.fieldID,
            passwordFieldIDs: [],
            username: suggestion.email,
            password: "",
            highlightColor: "#E8F1FF",
            submitAfterFill: false
        )

        evaluate(scriptMethod: "fillCredentials", payload: request)
        dismissOverlay()
    }

    func updateSelection(to index: Int, for overlay: PasswordAutofillOverlayState) {
        let boundedIndex = boundedSelectionIndex(index, for: overlay)
        applySelectionIndex(boundedIndex, forFieldID: overlay.focus.fieldID)
    }

    @MainActor
    func openPasswordsManager() {
        openPasswordsWindow()
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

        let suggestions = Self.resolveSuggestions(
            for: focus,
            matchingEntries: passwordManager.matchingEntries(for: pageURL, containerID: tab?.container.id),
            emailSuggestions: passwordManager.emailSuggestions(for: tab?.container.id),
            generatedPassword: focus.action == .createAccount ? passwordManager.generateStrongPassword() : nil
        )

        guard !suggestions.savedPasswordEntries.isEmpty
            || !suggestions.emailSuggestions.isEmpty
            || suggestions.generatedPassword != nil
        else {
            clearAutofillState()
            return
        }

        let overlayState = PasswordAutofillOverlayState(
            focus: PasswordBridgeFocusPayload(
                fieldID: focus.fieldID,
                hostname: normalizedHost,
                action: focus.action,
                fieldKind: focus.fieldKind,
                usernameFieldID: focus.usernameFieldID,
                passwordFieldIDs: focus.passwordFieldIDs,
                rect: focus.rect
            ),
            savedPasswordEntries: suggestions.savedPasswordEntries,
            emailSuggestions: suggestions.emailSuggestions,
            generatedPassword: suggestions.generatedPassword,
            selectedSuggestionIndex: suggestions.selectedSuggestionIndex
        )

        tab?.passwordTriggerOverlayState = overlayState
        tab?.passwordOverlayState = overlayState
        setOverlayKeyboardActive(true)
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
            .matchingEntries(for: pageURL, containerID: tab?.container.id)
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

        let saveAction: () -> Void = {
            _ = try? self.passwordManager.upsertCredential(
                for: pageURL,
                username: trimmedUsername,
                password: trimmedPassword,
                containerID: self.tab?.container.id
            )
        }

        Task { @MainActor [weak self] in
            self?.presentSavePrompt(
                prompt,
                normalizedHost: normalizedHost,
                saveAction: saveAction
            )
        }
    }

    @MainActor
    private func presentSavePrompt(
        _ prompt: PasswordSavePromptDetails,
        normalizedHost: String,
        saveAction: @escaping () -> Void
    ) {
        guard let window = presentationWindow() else {
            return
        }

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
    }

    @MainActor
    private func presentationWindow() -> NSWindow? {
        if let window = tab?.pageWindow {
            return window
        }

        if let appDelegate = NSApp.delegate as? AppDelegate {
            return appDelegate.getWindow()
        }

        return NSApp.keyWindow
            ?? NSApp.windows.first(where: { $0.isVisible })
            ?? NSApp.windows.first
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
                fieldKind: overlay.focus.fieldKind,
                usernameFieldID: overlay.focus.usernameFieldID,
                passwordFieldIDs: overlay.focus.passwordFieldIDs,
                rect: rect
            ),
            savedPasswordEntries: overlay.savedPasswordEntries,
            emailSuggestions: overlay.emailSuggestions,
            generatedPassword: overlay.generatedPassword,
            selectedSuggestionIndex: overlay.selectedSuggestionIndex
        )
    }

    private func overlayState(
        _ overlay: PasswordAutofillOverlayState,
        updatingSelectionIndexTo selectionIndex: Int
    ) -> PasswordAutofillOverlayState {
        PasswordAutofillOverlayState(
            focus: overlay.focus,
            savedPasswordEntries: overlay.savedPasswordEntries,
            emailSuggestions: overlay.emailSuggestions,
            generatedPassword: overlay.generatedPassword,
            selectedSuggestionIndex: selectionIndex
        )
    }

    private func evaluate(scriptMethod: String, payload: some Encodable) {
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
        tab?.evaluateJavaScript(script)
    }

    private func setOverlayKeyboardActive(_ isActive: Bool) {
        guard tab?.browserPage != nil else { return }
        evaluate(scriptMethod: "setOverlayKeyboardActive", payload: isActive)
    }

    private func handleKeyCommand(_ command: PasswordAutofillKeyCommand) {
        switch command {
        case .moveUp:
            moveSelection(by: -1)
        case .moveDown:
            moveSelection(by: 1)
        case .activate:
            activateCurrentSelection()
        case .dismiss:
            dismissOverlay()
        }
    }

    func moveSelection(by delta: Int) {
        guard let overlay = tab?.passwordOverlayState else { return }
        let suggestionCount = overlay.suggestions.count
        guard suggestionCount > 0 else { return }

        let nextIndex = min(max(overlay.selectedSuggestionIndex + delta, 0), suggestionCount - 1)
        applySelectionIndex(nextIndex, forFieldID: overlay.focus.fieldID)
    }

    func activateCurrentSelection() {
        guard let overlay = tab?.passwordOverlayState,
              overlay.suggestions.indices.contains(overlay.selectedSuggestionIndex)
        else {
            return
        }

        switch overlay.suggestions[overlay.selectedSuggestionIndex] {
        case .generatedPassword:
            fillGeneratedPassword(for: overlay)
        case let .savedCredential(entry):
            autofill(entry, for: overlay)
        case let .email(suggestion):
            fillEmailSuggestion(suggestion, for: overlay)
        }
    }

    private func applySelectionIndex(_ selectionIndex: Int, forFieldID fieldID: String) {
        if let overlay = tab?.passwordOverlayState,
           overlay.focus.fieldID == fieldID
        {
            tab?.passwordOverlayState = overlayState(overlay, updatingSelectionIndexTo: selectionIndex)
        }

        if let triggerOverlay = tab?.passwordTriggerOverlayState,
           triggerOverlay.focus.fieldID == fieldID
        {
            tab?.passwordTriggerOverlayState = overlayState(triggerOverlay, updatingSelectionIndexTo: selectionIndex)
        }
    }

    private func boundedSelectionIndex(_ selectionIndex: Int, for overlay: PasswordAutofillOverlayState) -> Int {
        let suggestionCount = overlay.suggestions.count
        guard suggestionCount > 0 else { return -1 }
        return min(max(selectionIndex, 0), suggestionCount - 1)
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

    static func resolveSuggestions(
        for focus: PasswordBridgeFocusPayload,
        matchingEntries: [SavedPasswordSummary],
        emailSuggestions: [PasswordEmailSuggestion],
        generatedPassword: String?
    ) -> PasswordAutofillOverlayState {
        let savedPasswordEntries: [SavedPasswordSummary]
        let filteredEmailSuggestions: [PasswordEmailSuggestion]
        let filteredGeneratedPassword: String?

        switch (focus.action, focus.fieldKind) {
        case (.createAccount, .password):
            savedPasswordEntries = []
            filteredEmailSuggestions = []
            filteredGeneratedPassword = generatedPassword
        case (.createAccount, .email):
            savedPasswordEntries = []
            filteredEmailSuggestions = emailSuggestions
            filteredGeneratedPassword = nil
        case (.createAccount, .username):
            savedPasswordEntries = []
            filteredEmailSuggestions = []
            filteredGeneratedPassword = nil
        case (.login, _):
            savedPasswordEntries = matchingEntries
            filteredEmailSuggestions = []
            filteredGeneratedPassword = nil
        }

        return PasswordAutofillOverlayState(
            focus: focus,
            savedPasswordEntries: savedPasswordEntries,
            emailSuggestions: filteredEmailSuggestions,
            generatedPassword: filteredGeneratedPassword,
            selectedSuggestionIndex: (savedPasswordEntries.isEmpty && filteredEmailSuggestions
                .isEmpty && filteredGeneratedPassword == nil) ? -1 : 0
        )
    }
}
