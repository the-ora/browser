import Foundation

enum PasswordManagerProviderKind: String, CaseIterable, Codable, Identifiable {
    case ora
    case onePassword
    case bitwarden

    var id: String {
        rawValue
    }
}

enum PasswordManagerAutofillMode {
    case builtInOverlay
    case nativeProviderOverlay
}

struct PasswordManagerProviderDescriptor: Identifiable, Hashable {
    let kind: PasswordManagerProviderKind
    let title: String
    let summary: String
    let vaultStoredInOra: Bool
    let autofillMode: PasswordManagerAutofillMode
    let isAvailable: Bool

    var id: PasswordManagerProviderKind {
        kind
    }

    var usesBuiltInVault: Bool {
        vaultStoredInOra
    }

    var usesBuiltInOverlay: Bool {
        autofillMode == .builtInOverlay
    }
}

final class PasswordManagerProviderRegistry {
    static let shared = PasswordManagerProviderRegistry()

    let providers: [PasswordManagerProviderDescriptor] = [
        PasswordManagerProviderDescriptor(
            kind: .ora,
            title: "Ora Passwords",
            summary: "Store encrypted credentials in Ora and show Ora's autofill overlay.",
            vaultStoredInOra: true,
            autofillMode: .builtInOverlay,
            isAvailable: true
        )
        // PasswordManagerProviderDescriptor(
        //     kind: .onePassword,
        //     title: "1Password",
        //     summary: "Reserved for a native 1Password integration with 1Password's own autofill surface.",
        //     vaultStoredInOra: false,
        //     autofillMode: .nativeProviderOverlay,
        //     isAvailable: false
        // ),
        // PasswordManagerProviderDescriptor(
        //     kind: .bitwarden,
        //     title: "Bitwarden",
        //     summary: "Reserved for a native Bitwarden integration with Bitwarden's own autofill surface.",
        //     vaultStoredInOra: false,
        //     autofillMode: .nativeProviderOverlay,
        //     isAvailable: false
        // )
    ]

    private init() {}

    func descriptor(for kind: PasswordManagerProviderKind) -> PasswordManagerProviderDescriptor {
        providers.first(where: { $0.kind == kind }) ?? providers[0]
    }
}
