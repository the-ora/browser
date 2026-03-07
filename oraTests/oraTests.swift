//
//  oraTests.swift
//  oraTests
//
//  Created by keni on 6/21/25.
//

@testable import ora
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
}
