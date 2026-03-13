import AppKit
import Foundation
import LocalAuthentication
import Security
import SwiftData

struct SavedPasswordMetadata: Codable, Hashable {
    var id: String
    var origin: String?
    var host: String
    var username: String
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var containerID: UUID?
}

struct SavedPasswordSummary: Identifiable, Hashable {
    let metadata: SavedPasswordMetadata
    let persistentReference: Data

    var id: String {
        metadata.id
    }

    var host: String {
        metadata.host
    }

    var origin: String? {
        metadata.origin
    }

    var username: String {
        metadata.username
    }

    var createdAt: Date {
        metadata.createdAt
    }

    var updatedAt: Date {
        metadata.updatedAt
    }

    var lastUsedAt: Date? {
        metadata.lastUsedAt
    }

    var containerID: UUID? {
        metadata.containerID
    }

    var displayUsername: String {
        username.isEmpty ? "No username" : username
    }
}

struct PasswordEmailSuggestion: Identifiable, Hashable {
    let email: String
    let host: String
    let lastUsedAt: Date?
    let updatedAt: Date

    var id: String {
        email.lowercased()
    }
}

final class PasswordManagerService: ObservableObject {
    static let shared = PasswordManagerService()

    @Published private(set) var entries: [SavedPasswordSummary] = []
    @Published private(set) var lastErrorMessage: String?

    private let serviceName = "com.orabrowser.app.passwords"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        refresh()
    }

    func refresh() {
        do {
            let loadedEntries = try loadEntries()
            if try migrateLegacyEntriesIfNeeded(loadedEntries) {
                entries = try loadEntries()
            } else {
                entries = loadedEntries
            }
            lastErrorMessage = nil
        } catch {
            entries = []
            lastErrorMessage = error.localizedDescription
        }
    }

    func matchingEntries(for url: URL) -> [SavedPasswordSummary] {
        matchingEntries(for: url, containerID: nil)
    }

    func matchingEntries(for url: URL, containerID: UUID?) -> [SavedPasswordSummary] {
        guard let origin = Self.normalizedOrigin(from: url),
              let host = Self.normalizedHost(from: url)
        else {
            return []
        }

        let shouldAllowLegacyHostMatch = Self.isSecureDefaultPort(url)
        let alternateHost = host.hasPrefix("www.")
            ? String(host.dropFirst(4))
            : "www.\(host)"

        return scopedEntries(for: containerID)
            .filter { entry in
                if entry.origin == origin {
                    return true
                }

                guard shouldAllowLegacyHostMatch, entry.origin == nil else {
                    return false
                }

                let entryHost = Self.normalizeHost(entry.host)
                return entryHost == host || entryHost == alternateHost
            }
            .sorted {
                let lhsDate = $0.lastUsedAt ?? $0.updatedAt
                let rhsDate = $1.lastUsedAt ?? $1.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.displayUsername.localizedCaseInsensitiveCompare($1.displayUsername) == .orderedAscending
            }
    }

    func emailSuggestions(limit: Int = 4) -> [PasswordEmailSuggestion] {
        emailSuggestions(for: nil, limit: limit)
    }

    func emailSuggestions(for containerID: UUID?, limit: Int = 4) -> [PasswordEmailSuggestion] {
        var seenEmails = Set<String>()

        return scopedEntries(for: containerID)
            .sorted {
                let lhsDate = $0.lastUsedAt ?? $0.updatedAt
                let rhsDate = $1.lastUsedAt ?? $1.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.displayUsername.localizedCaseInsensitiveCompare($1.displayUsername) == .orderedAscending
            }
            .compactMap { entry -> PasswordEmailSuggestion? in
                let trimmedEmail = entry.username.trimmingCharacters(in: .whitespacesAndNewlines)
                guard Self.looksLikeEmail(trimmedEmail) else {
                    return nil
                }

                let normalizedEmail = trimmedEmail.lowercased()
                guard seenEmails.insert(normalizedEmail).inserted else {
                    return nil
                }

                return PasswordEmailSuggestion(
                    email: trimmedEmail,
                    host: entry.host,
                    lastUsedAt: entry.lastUsedAt,
                    updatedAt: entry.updatedAt
                )
            }
            .prefix(limit)
            .map(\.self)
    }

    func entries(for containerID: UUID?) -> [SavedPasswordSummary] {
        scopedEntries(for: containerID)
    }

    func revealPassword(for entry: SavedPasswordSummary) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecValuePersistentRef as String: entry.persistentReference,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw PasswordManagerError.keychainStatus(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            throw PasswordManagerError.invalidStoredPassword
        }

        return password
    }

    func upsertCredential(for url: URL, username: String, password: String) throws {
        try upsertCredential(for: url, username: username, password: password, containerID: nil)
    }

    func upsertCredential(for url: URL, username: String, password: String, containerID: UUID?) throws {
        guard let normalizedOrigin = Self.normalizedOrigin(from: url),
              let normalizedHost = Self.normalizedHost(from: url)
        else {
            throw PasswordManagerError.invalidCredentialOrigin
        }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        if let existing = scopedEntries(for: containerID, includeLegacyFallback: true).first(where: {
            let originMatches = $0.origin == normalizedOrigin
            let legacyHostMatches = $0.origin == nil && Self.normalizeHost($0.host) == normalizedHost
            return (originMatches || legacyHostMatches) && $0.username == trimmedUsername
        }) {
            let metadata = SavedPasswordMetadata(
                id: existing.id,
                origin: normalizedOrigin,
                host: normalizedHost,
                username: trimmedUsername,
                createdAt: existing.createdAt,
                updatedAt: now,
                lastUsedAt: existing.lastUsedAt,
                containerID: containerID
            )

            let attributes: [String: Any] = try [
                kSecAttrGeneric as String: encode(metadata: metadata),
                kSecAttrLabel as String: normalizedHost,
                kSecAttrComment as String: trimmedUsername,
                kSecValueData as String: Data(password.utf8)
            ]

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecValuePersistentRef as String: existing.persistentReference
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw PasswordManagerError.keychainStatus(status)
            }
        } else {
            let metadata = SavedPasswordMetadata(
                id: UUID().uuidString,
                origin: normalizedOrigin,
                host: normalizedHost,
                username: trimmedUsername,
                createdAt: now,
                updatedAt: now,
                lastUsedAt: nil,
                containerID: containerID
            )

            let item: [String: Any] = try [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: metadata.id,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
                kSecAttrGeneric as String: encode(metadata: metadata),
                kSecAttrLabel as String: normalizedHost,
                kSecAttrComment as String: trimmedUsername,
                kSecValueData as String: Data(password.utf8)
            ]

            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw PasswordManagerError.keychainStatus(status)
            }
        }

        refresh()
    }

    func markUsed(_ entry: SavedPasswordSummary) {
        do {
            let metadata = SavedPasswordMetadata(
                id: entry.id,
                origin: entry.origin,
                host: entry.host,
                username: entry.username,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                lastUsedAt: Date(),
                containerID: entry.containerID
            )

            let attributes: [String: Any] = try [
                kSecAttrGeneric as String: encode(metadata: metadata)
            ]
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecValuePersistentRef as String: entry.persistentReference
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw PasswordManagerError.keychainStatus(status)
            }

            refresh()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func delete(_ entry: SavedPasswordSummary) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecValuePersistentRef as String: entry.persistentReference
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasswordManagerError.keychainStatus(status)
        }

        refresh()
    }

    func deleteEntries(for containerID: UUID) throws {
        let scopedEntries = entries(for: containerID)

        defer {
            refresh()
        }

        do {
            for entry in scopedEntries {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecValuePersistentRef as String: entry.persistentReference
                ]

                let status = SecItemDelete(query as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw PasswordManagerError.keychainStatus(status)
                }
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func generateStrongPassword() -> String {
        Self.generateStrongPassword()
    }

    static func generateStrongPassword() -> String {
        if #available(macOS 11.0, *),
           let generated = SecCreateSharedWebCredentialPassword() as String?
        {
            return generated
        }

        let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
        let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
        let digits = Array("3456789")
        let symbols = Array("!@#$%^&*")
        let allCharacters = uppercase + lowercase + digits + symbols

        var password = [
            uppercase.randomElement(),
            lowercase.randomElement(),
            digits.randomElement(),
            symbols.randomElement()
        ].compactMap { $0 }

        while password.count < 20 {
            if let character = allCharacters.randomElement() {
                password.append(character)
            }
        }

        return String(password.shuffled())
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func canUseBiometricAuthentication() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func currentAccountDisplayName() -> String {
        NSFullUserName()
    }

    func copyToPasteboard(_ value: String) {
        copyToPasteboard(value, clearingAfter: nil)
    }

    func copySensitiveToPasteboard(_ value: String) {
        copyToPasteboard(value, clearingAfter: 90)
    }

    static func normalizeHost(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    static func normalizedHost(from url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else {
            return nil
        }
        return normalizeHost(host)
    }

    static func normalizedOrigin(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = normalizedHost(from: url)
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host

        if let port = url.port, port != defaultPort(for: scheme) {
            components.port = port
        }

        return components.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty,
              let atIndex = trimmedValue.firstIndex(of: "@")
        else {
            return false
        }

        let localPart = trimmedValue[..<atIndex]
        let domainStart = trimmedValue.index(after: atIndex)
        guard domainStart < trimmedValue.endIndex else {
            return false
        }

        let domainPart = trimmedValue[domainStart...]
        return !localPart.isEmpty
            && domainPart.contains(".")
            && !domainPart.hasPrefix(".")
            && !domainPart.hasSuffix(".")
    }

    private func loadEntries() throws -> [SavedPasswordSummary] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasswordManagerError.keychainStatus(status)
        }

        guard let records = result as? [[String: Any]] else {
            return []
        }

        return records.compactMap { record -> SavedPasswordSummary? in
            guard let persistentReference = record[kSecValuePersistentRef as String] as? Data else {
                return nil
            }

            if let genericData = record[kSecAttrGeneric as String] as? Data,
               let metadata = try? decoder.decode(SavedPasswordMetadata.self, from: genericData)
            {
                return SavedPasswordSummary(metadata: metadata, persistentReference: persistentReference)
            }

            guard let account = record[kSecAttrAccount as String] as? String,
                  let host = record[kSecAttrLabel as String] as? String
            else {
                return nil
            }

            let fallbackMetadata = SavedPasswordMetadata(
                id: account,
                origin: nil,
                host: host,
                username: record[kSecAttrComment as String] as? String ?? "",
                createdAt: Date.distantPast,
                updatedAt: Date.distantPast,
                lastUsedAt: nil,
                containerID: nil
            )
            return SavedPasswordSummary(metadata: fallbackMetadata, persistentReference: persistentReference)
        }
        .sorted {
            if $0.host != $1.host {
                return $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending
            }
            return $0.displayUsername.localizedCaseInsensitiveCompare($1.displayUsername) == .orderedAscending
        }
    }

    private func encode(metadata: SavedPasswordMetadata) throws -> Data {
        try encoder.encode(metadata)
    }

    private func scopedEntries(for containerID: UUID?, includeLegacyFallback: Bool = false) -> [SavedPasswordSummary] {
        guard let containerID else {
            return entries
        }

        return entries.filter { entry in
            if entry.containerID == containerID {
                return true
            }

            return includeLegacyFallback && entry.containerID == nil
        }
    }

    private func migrateLegacyEntriesIfNeeded(_ loadedEntries: [SavedPasswordSummary]) throws -> Bool {
        let legacyEntries = loadedEntries.filter { $0.containerID == nil }
        guard !legacyEntries.isEmpty,
              let destinationContainerID = legacyMigrationContainerID()
        else {
            return false
        }

        for entry in legacyEntries {
            let metadata = SavedPasswordMetadata(
                id: entry.id,
                origin: entry.origin,
                host: entry.host,
                username: entry.username,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                lastUsedAt: entry.lastUsedAt,
                containerID: destinationContainerID
            )

            let attributes: [String: Any] = try [
                kSecAttrGeneric as String: encode(metadata: metadata)
            ]
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecValuePersistentRef as String: entry.persistentReference
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw PasswordManagerError.keychainStatus(status)
            }
        }

        return true
    }

    private func legacyMigrationContainerID() -> UUID? {
        guard let modelContainer = try? ModelConfiguration.createOraContainer(isPrivate: false) else {
            return nil
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<TabContainer>(
            sortBy: [SortDescriptor(\TabContainer.createdAt, order: .forward)]
        )

        return try? context.fetch(descriptor).first?.id
    }

    private func copyToPasteboard(_ value: String, clearingAfter timeout: TimeInterval?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        guard let timeout else {
            return
        }

        let expectedChangeCount = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            let currentPasteboard = NSPasteboard.general
            guard currentPasteboard.changeCount == expectedChangeCount,
                  currentPasteboard.string(forType: .string) == value
            else {
                return
            }

            currentPasteboard.clearContents()
        }
    }

    private static func isSecureDefaultPort(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else {
            return false
        }

        return url.port == nil || url.port == defaultPort(for: "https")
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return -1
        }
    }
}

enum PasswordManagerError: LocalizedError {
    case invalidStoredPassword
    case invalidCredentialOrigin
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidStoredPassword:
            return "Ora couldn't decode the stored password."
        case .invalidCredentialOrigin:
            return "Ora can only save passwords for web origins."
        case let .keychainStatus(status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error \(status)."
        }
    }
}
