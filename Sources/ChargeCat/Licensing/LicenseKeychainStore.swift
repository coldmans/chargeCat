import Foundation
import LocalAuthentication
import Security

struct StoredLicenseCredentials {
    let provider: LicenseProvider
    let licenseKey: String
    let installationId: String
    let instanceId: String?
    let customerEmail: String?
}

enum KeychainInteractionPolicy {
    case allowUI
    case failIfPromptRequired
}

struct LicenseKeychainStore {
    private enum Account: String, CaseIterable {
        case provider = "provider"
        case licenseKey = "license-key"
        case installationId = "installation-id"
        case instanceId = "instance-id"
        case customerEmail = "customer-email"
    }

    private let service: String

    init(service: String = LicensingConfiguration.keychainService) {
        self.service = service
    }

    func loadCredentials(interactionPolicy: KeychainInteractionPolicy = .allowUI) -> StoredLicenseCredentials? {
        guard let licenseKey = read(.licenseKey, interactionPolicy: interactionPolicy),
              let installationId = read(.installationId, interactionPolicy: interactionPolicy)
        else {
            return nil
        }

        return StoredLicenseCredentials(
            provider: LicenseProvider(rawValue: read(.provider, interactionPolicy: interactionPolicy) ?? "") ?? .lemon,
            licenseKey: licenseKey,
            installationId: installationId,
            instanceId: read(.instanceId, interactionPolicy: interactionPolicy),
            customerEmail: read(.customerEmail, interactionPolicy: interactionPolicy)
        )
    }

    func loadCustomerEmail(interactionPolicy: KeychainInteractionPolicy = .allowUI) -> String? {
        read(.customerEmail, interactionPolicy: interactionPolicy)
    }

    func loadMaskedLicenseKey(interactionPolicy: KeychainInteractionPolicy = .allowUI) -> String? {
        guard let licenseKey = read(.licenseKey, interactionPolicy: interactionPolicy), licenseKey.count > 8 else { return nil }
        let prefix = licenseKey.prefix(4)
        let suffix = licenseKey.suffix(4)
        return "\(prefix)••••\(suffix)"
    }

    func hasLicenseKey(interactionPolicy: KeychainInteractionPolicy = .allowUI) -> Bool {
        read(.licenseKey, interactionPolicy: interactionPolicy)?.isEmpty == false
    }

    func installationId(interactionPolicy: KeychainInteractionPolicy = .allowUI) -> String {
        if let existing = read(.installationId, interactionPolicy: interactionPolicy), existing.isEmpty == false {
            return existing
        }

        if interactionPolicy == .failIfPromptRequired {
            return UUID().uuidString.lowercased()
        }

        let generated = UUID().uuidString.lowercased()
        write(generated, for: .installationId)
        return generated
    }

    func saveActivatedLicense(
        provider: LicenseProvider,
        licenseKey: String,
        instanceId: String,
        installationId: String,
        customerEmail: String?
    ) {
        write(provider.rawValue, for: .provider)
        write(licenseKey, for: .licenseKey)
        write(instanceId, for: .instanceId)
        write(installationId, for: .installationId)

        if let customerEmail, customerEmail.isEmpty == false {
            write(customerEmail, for: .customerEmail)
        } else {
            delete(.customerEmail)
        }
    }

    func clearActivation() {
        delete(.provider)
        delete(.licenseKey)
        delete(.instanceId)
        delete(.customerEmail)
    }

    private func read(
        _ account: Account,
        interactionPolicy: KeychainInteractionPolicy
    ) -> String? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        if interactionPolicy == .failIfPromptRequired {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    private func write(_ value: String, for account: Account) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        var item = query
        item[kSecValueData] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: Account) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
