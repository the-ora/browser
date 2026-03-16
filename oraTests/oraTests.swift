//
//  oraTests.swift
//  oraTests
//
//  Created by keni on 6/21/25.
//

import Foundation
@testable import Ora
import Testing

struct OraTests {
    @Test func normalizesHostsForPasswordMatching() {
        #expect(PasswordManagerService.normalizeHost("WWW.Example.COM.") == "www.example.com")
        #expect(PasswordManagerService.normalizeHost(" login.example.com ") == "login.example.com")
    }

    @Test func normalizesOriginsForPasswordMatching() throws {
        let secureURL = try #require(URL(string: "https://WWW.Example.COM/login"))
        let defaultPortURL = try #require(URL(string: "https://example.com:443/account"))
        let customPortURL = try #require(URL(string: "https://example.com:8443/account"))
        let insecureURL = try #require(URL(string: "http://example.com/login"))
        let unsupportedURL = try #require(URL(string: "file:///tmp/index.html"))

        #expect(PasswordManagerService.normalizedOrigin(from: secureURL) == "https://www.example.com")
        #expect(PasswordManagerService.normalizedOrigin(from: defaultPortURL) == "https://example.com")
        #expect(PasswordManagerService.normalizedOrigin(from: customPortURL) == "https://example.com:8443")
        #expect(PasswordManagerService.normalizedOrigin(from: insecureURL) == "http://example.com")
        #expect(PasswordManagerService.normalizedOrigin(from: unsupportedURL) == nil)
    }

    @Test func generatesStrongPasswords() {
        let password = PasswordManagerService.generateStrongPassword()

        #expect(password.count >= 12)
        #expect(password.contains("-") || password.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    @Test func warnsBeforeSavingPasswordsOnInsecurePages() throws {
        let insecureURL = try #require(URL(string: "http://example.com/login"))

        let prompt = PasswordAutofillCoordinator.savePromptDetails(
            for: insecureURL,
            username: "alice@example.com",
            normalizedHost: "example.com",
            isUpdate: false
        )

        #expect(prompt.showsSecurityWarning)
        #expect(prompt.title == "Save Password on Insecure Page")
        #expect(prompt.confirmButtonTitle == "Save Anyway")
        #expect(prompt.neverButtonTitle == "Never on This Site")
        #expect(prompt.message.contains("insecure connection (http://)"))
    }

    @Test func keepsStandardPromptOnSecurePages() throws {
        let secureURL = try #require(URL(string: "https://example.com/login"))

        let prompt = PasswordAutofillCoordinator.savePromptDetails(
            for: secureURL,
            username: "",
            normalizedHost: "example.com",
            isUpdate: true
        )

        #expect(prompt.showsSecurityWarning == false)
        #expect(prompt.title == "Update Password")
        #expect(prompt.confirmButtonTitle == "Update Password")
        #expect(prompt.neverButtonTitle == "Never on This Site")
        #expect(prompt.message == "Update the saved password for example.com?")
    }

    @Test func recognizesEmailUsernamesForSignupSuggestions() {
        #expect(PasswordManagerService.looksLikeEmail("alice@example.com"))
        #expect(PasswordManagerService.looksLikeEmail(" alice@example.com "))
        #expect(PasswordManagerService.looksLikeEmail("alice") == false)
        #expect(PasswordManagerService.looksLikeEmail("alice@localhost") == false)
    }

    @Test func limitsSignupSuggestionsByFocusedFieldKind() {
        let entry = SavedPasswordSummary(
            metadata: SavedPasswordMetadata(
                id: "entry-1",
                origin: "https://example.com",
                host: "example.com",
                username: "saved@example.com",
                createdAt: .distantPast,
                updatedAt: .distantPast,
                lastUsedAt: nil
            ),
            persistentReference: Data()
        )
        let emailSuggestion = PasswordEmailSuggestion(
            email: "person@example.com",
            host: "another.com",
            lastUsedAt: nil,
            updatedAt: .distantPast
        )

        let passwordFocus = PasswordBridgeFocusPayload(
            fieldID: "password-field",
            hostname: "example.com",
            action: .createAccount,
            fieldKind: .password,
            usernameFieldID: "email-field",
            passwordFieldIDs: ["password-field"],
            rect: PasswordBridgeRect(originX: 0, originY: 0, width: 100, height: 20)
        )
        let passwordSuggestions = PasswordAutofillCoordinator.resolveSuggestions(
            for: passwordFocus,
            matchingEntries: [entry],
            emailSuggestions: [emailSuggestion],
            generatedPassword: "StrongPass123!"
        )

        #expect(passwordSuggestions.generatedPassword == "StrongPass123!")
        #expect(passwordSuggestions.savedPasswordEntries.isEmpty)
        #expect(passwordSuggestions.emailSuggestions.isEmpty)

        let emailFocus = PasswordBridgeFocusPayload(
            fieldID: "email-field",
            hostname: "example.com",
            action: .createAccount,
            fieldKind: .email,
            usernameFieldID: "email-field",
            passwordFieldIDs: ["password-field"],
            rect: PasswordBridgeRect(originX: 0, originY: 0, width: 100, height: 20)
        )
        let emailSuggestions = PasswordAutofillCoordinator.resolveSuggestions(
            for: emailFocus,
            matchingEntries: [entry],
            emailSuggestions: [emailSuggestion],
            generatedPassword: "StrongPass123!"
        )

        #expect(emailSuggestions.generatedPassword == nil)
        #expect(emailSuggestions.savedPasswordEntries.isEmpty)
        #expect(emailSuggestions.emailSuggestions == [emailSuggestion])
    }
}
