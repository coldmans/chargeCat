import Foundation

enum LicenseProvider: String, Codable {
    case lemon
    case chargeCat
}

protocol Licensing {
    func activate(licenseKey: String, customerEmail: String?) async throws -> LicenseState
    func validateCachedLicense(force: Bool, allowsAuthenticationUI: Bool) async -> LicenseState
    func deactivateCurrentMac() async throws -> LicenseState
}

enum LicensingError: LocalizedError {
    case notConfigured
    case missingStoredLicense
    case invalid(message: String, suggestedState: LicenseState)
    case revoked(message: String, suggestedState: LicenseState)
    case transient(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Pro checkout isn't configured in this build yet."
        case .missingStoredLicense:
            return "No saved Pro license was found on this Mac."
        case let .invalid(message, _),
             let .revoked(message, _),
             let .transient(message):
            return message
        }
    }

    var suggestedState: LicenseState? {
        switch self {
        case let .invalid(_, suggestedState),
             let .revoked(_, suggestedState):
            return suggestedState
        case .notConfigured, .missingStoredLicense, .transient:
            return nil
        }
    }
}
