//
//  oraTests.swift
//  oraTests
//
//  Created by keni on 6/21/25.
//

import Foundation
@testable import Ora
import Testing

private final class RequestCountingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var handledRequestCount = 0

    static func reset() {
        lock.lock()
        handledRequestCount = 0
        lock.unlock()
    }

    static var requestCount: Int {
        lock.lock()
        let count = handledRequestCount
        lock.unlock()
        return count
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.handledRequestCount += 1
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com/filter.txt")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("||ads.example^".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

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

    @Test func storesPrivacySettingsPerSpaceIndependently() {
        let store = SettingsStore.shared
        let firstContainerID = UUID()
        let secondContainerID = UUID()
        let baselineSecondSettings = store.privacySettings(for: secondContainerID)

        defer {
            store.removeContainerSettings(for: firstContainerID)
            store.removeContainerSettings(for: secondContainerID)
        }

        let updatedSettings = SpacePrivacySettings(
            blockThirdPartyTrackers: true,
            blockFingerprinting: true,
            adBlocking: true,
            adBlock: SpaceAdBlockSettings(
                enabled: true,
                enabledBuiltinListIDs: [
                    FilterListCatalogService.adGuardBaseID,
                    FilterListCatalogService.adGuardAnnoyancesID
                ],
                enabledCustomListIDs: ["custom-test-list"],
                updateMode: .aggressiveAuto
            ),
            cookiesPolicy: .blockThirdParty
        )

        store.setPrivacySettings(updatedSettings, for: firstContainerID)

        #expect(store.privacySettings(for: firstContainerID) == updatedSettings)
        #expect(store.privacySettings(for: secondContainerID) == baselineSecondSettings)
    }

    @Test func removingContainerSettingsResetsSpacePrivacyOverrides() {
        let store = SettingsStore.shared
        let containerID = UUID()
        let baselineSettings = store.privacySettings(for: containerID)

        defer {
            store.removeContainerSettings(for: containerID)
        }

        var updatedSettings = baselineSettings
        updatedSettings.cookiesPolicy = baselineSettings.cookiesPolicy == .blockAll ? .allowAll : .blockAll
        updatedSettings.adBlocking.toggle()

        store.setPrivacySettings(updatedSettings, for: containerID)
        #expect(store.privacySettings(for: containerID) == updatedSettings)

        store.removeContainerSettings(for: containerID)
        #expect(store.privacySettings(for: containerID) == baselineSettings)
    }

    @Test func seedsBuiltInAdBlockLists() {
        let builtinIDs = Set(SettingsStore.shared.adBlockFilterLists.filter(\.isBuiltin).map(\.id))

        #expect(builtinIDs.contains(FilterListCatalogService.adGuardBaseID))
        #expect(builtinIDs.contains(FilterListCatalogService.adGuardMobileAdsID))
        #expect(builtinIDs.contains(FilterListCatalogService.adGuardTrackingProtectionID))
        #expect(builtinIDs.contains(FilterListCatalogService.adGuardURLTrackingID))
        #expect(builtinIDs.contains(FilterListCatalogService.adGuardAnnoyancesID))
    }

    @Test func validatesCustomAdBlockURLs() {
        let service = FilterListUpdateService()

        #expect(service.isValidCustomListURL("https://example.com/filter.txt"))
        #expect(service.isValidCustomListURL("http://example.com/filter.txt"))
        #expect(service.isValidCustomListURL("ftp://example.com/filter.txt") == false)
        #expect(service.isValidCustomListURL("file:///tmp/filter.txt") == false)
    }

    @Test func persistsAdBlockUpdateModePerSpace() {
        let store = SettingsStore.shared
        let containerID = UUID()

        defer {
            store.removeContainerSettings(for: containerID)
        }

        var updatedSettings = store.privacySettings(for: containerID)
        updatedSettings.adBlock.updateMode = .aggressiveAuto
        store.setPrivacySettings(updatedSettings, for: containerID)

        #expect(store.privacySettings(for: containerID).adBlock.updateMode == .aggressiveAuto)
    }

    @Test func spacePrivacySettingsDefaultToFingerprintingOnAndCookiesAllowed() {
        let defaults = SpacePrivacySettings()

        #expect(defaults.blockFingerprinting)
        #expect(defaults.cookiesPolicy == .allowAll)
    }

    @Test func fingerprintingEnabledSpacesGenerateProtectionScripts() {
        let disabledScripts = BrowserPrivacyService.privacyScripts(
            for: SpacePrivacySettings(blockFingerprinting: false)
        )
        let enabledScripts = BrowserPrivacyService.privacyScripts(
            for: SpacePrivacySettings(blockFingerprinting: true)
        )

        #expect(disabledScripts.isEmpty)
        #expect(enabledScripts.count == 1)
        #expect(enabledScripts.first?.source.isEmpty == false)
    }

    @Test func fingerprintingScriptDoesNotDependOnCookiePolicy() {
        let allowAllScript = BrowserPrivacyService.privacyScripts(
            for: SpacePrivacySettings(blockFingerprinting: true, cookiesPolicy: .allowAll)
        ).first?.source
        let blockAllScript = BrowserPrivacyService.privacyScripts(
            for: SpacePrivacySettings(blockFingerprinting: true, cookiesPolicy: .blockAll)
        ).first?.source

        #expect(allowAllScript == blockAllScript)
    }

    @Test func balancedFingerprintingProfileIsInternallyCoherent() {
        let profile = FingerprintingProtectionProfile.balanced

        #expect(profile.language == profile.languages.first)
        #expect(profile.availWidth <= profile.screenWidth)
        #expect(profile.availHeight <= profile.screenHeight)
        #expect(profile.devicePixelRatio > 0)
        #expect(profile.platform == "MacIntel")
        #expect(profile.vendor == "Apple Computer, Inc.")
        #expect(profile.mediaDeviceKinds == ["audioinput", "audiooutput", "videoinput"])
    }

    @Test func fingerprintingScriptIncludesBalancedSurfaceNormalization() {
        let script = BrowserPrivacyService.fingerprintingProtectionScriptSource()

        #expect(script.contains("hardwareConcurrency"))
        #expect(script.contains("devicePixelRatio"))
        #expect(script.contains("enumerateDevices"))
        #expect(script.contains("toDataURL"))
        #expect(script.contains("OfflineAudioContext"))
        #expect(script.contains("WebGLRenderingContext"))
    }

    @Test func trackerRegexMatchesRootAndSubdomains() throws {
        let pattern = BrowserPrivacyService.regexForDomain("hotjar.com")
        let regex = try NSRegularExpression(pattern: pattern)
        let rootURL = "https://hotjar.com/script.js"
        let subdomainURL = "https://static.hotjar.com/c/hotjar.js"
        let otherURL = "https://not-hotjar-example.com/script.js"

        let rootRange = NSRange(rootURL.startIndex ..< rootURL.endIndex, in: rootURL)
        let subdomainRange = NSRange(subdomainURL.startIndex ..< subdomainURL.endIndex, in: subdomainURL)
        let otherRange = NSRange(otherURL.startIndex ..< otherURL.endIndex, in: otherURL)

        #expect(regex.firstMatch(in: rootURL, range: rootRange) != nil)
        #expect(regex.firstMatch(in: subdomainURL, range: subdomainRange) != nil)
        #expect(regex.firstMatch(in: otherURL, range: otherRange) == nil)
    }

    @Test func tracksUnsupportedRulesInCoverageSummary() throws {
        let compiler = ContentBlockerCompileService()
        let record = FilterListRecord(
            id: "test-filter",
            name: "Test Filter",
            summary: "Fixture list",
            sourceKind: .custom,
            sourceURL: "https://example.com/filter.txt",
            isRecommended: false,
            enabledByDefault: false
        )

        let rawText = """
        ||ads.example^
        example.com#%#console.log('advanced')
        """

        let artifacts = try compiler.compile(record: record, rawText: rawText)

        #expect(artifacts.coverage.totalRuleCount >= 2)
        #expect(artifacts.coverage.skippedRuleCount >= 1)
        #expect(artifacts.coverage.shardCount >= 1)
        #expect(artifacts.jsonShards.isEmpty == false)
    }

    @Test func artifactIdentifiersSupportDottedListIDs() throws {
        let temporaryArtifactsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ContentBlockerArtifactStore(baseURL: temporaryArtifactsURL)
        let coverage = FilterListCoverage(
            totalRuleCount: 1,
            convertedRuleCount: 1,
            skippedRuleCount: 0,
            safariRuleCount: 1,
            shardCount: 1
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryArtifactsURL)
        }

        try store.storeCompiledArtifacts(
            jsonShards: ["[{\"trigger\":{\"url-filter\":\".*\"},\"action\":{\"type\":\"block\"}}]"],
            coverage: coverage,
            for: "custom.list",
            revision: "revision123"
        )

        let identifiers = store.ruleListIdentifiers(for: "custom.list", revision: "revision123")

        #expect(identifiers.count == 1)
        #expect(store.encodedRuleList(for: identifiers[0])?.contains("\"type\":\"block\"") == true)
    }

    @Test func failedAdBlockRefreshPreservesLastKnownGoodRevision() {
        let record = FilterListRecord(
            id: "test-filter",
            name: "Test Filter",
            summary: "Fixture list",
            sourceKind: .custom,
            sourceURL: "https://example.com/filter.txt",
            isRecommended: false,
            enabledByDefault: false,
            status: .ready,
            activeRevision: "last-good-revision",
            coverage: FilterListCoverage(
                totalRuleCount: 10,
                convertedRuleCount: 8,
                skippedRuleCount: 2,
                safariRuleCount: 8,
                shardCount: 1
            )
        )

        let failed = AdBlockService.failedRecord(record, error: AdBlockServiceError.emptyFilterList("Test Filter"))

        #expect(failed.activeRevision == "last-good-revision")
        #expect(failed.status == .failed)
    }

    @Test func settingsRefreshStaysOfflineWithoutCachedRawList() async {
        let store = SettingsStore.shared
        let baselineLists = store.adBlockFilterLists
        let containerID = UUID()
        let temporaryArtifactsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let record = FilterListRecord(
            id: "offline-only-filter",
            name: "Offline Only Filter",
            summary: "Offline refresh regression fixture",
            sourceKind: .custom,
            sourceURL: "https://example.com/filter.txt",
            isRecommended: false,
            enabledByDefault: false,
            status: .ready,
            activeRevision: "existing-revision"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestCountingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = AdBlockService(
            updateService: FilterListUpdateService(session: session),
            artifactStore: ContentBlockerArtifactStore(baseURL: temporaryArtifactsURL)
        )

        var settings = store.privacySettings(for: containerID)
        settings.adBlock.enabled = true
        settings.adBlock.updateMode = .manualOnly
        settings.adBlock.enabledBuiltinListIDs = []
        settings.adBlock.enabledCustomListIDs = [record.id]

        RequestCountingURLProtocol.reset()
        store.upsertAdBlockFilterList(record)
        store.setPrivacySettings(settings, for: containerID)

        defer {
            store.setAdBlockFilterLists(baselineLists)
            store.removeContainerSettings(for: containerID)
            try? FileManager.default.removeItem(at: temporaryArtifactsURL)
        }

        let didChange = await service.refreshSpace(containerId: containerID, reason: .settingsChanged)
        let refreshedRecord = store.adBlockFilterList(id: record.id)

        #expect(didChange == false)
        #expect(RequestCountingURLProtocol.requestCount == 0)
        #expect(refreshedRecord?.status == .failed)
        #expect(refreshedRecord?.lastErrorMessage == AdBlockServiceError.missingCachedList(record.name)
            .errorDescription)
        #expect(refreshedRecord?.activeRevision == record.activeRevision)
    }
}
