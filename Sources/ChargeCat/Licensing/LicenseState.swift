import Foundation

enum EntitlementTier: String, Codable {
    case free
    case pro
}

enum LicenseStatus: String, Codable {
    case free
    case proVerified
    case proCached
    case revoked
    case invalid

    var allowsProAccess: Bool {
        self == .proVerified || self == .proCached
    }

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .proVerified:
            return "Pro Verified"
        case .proCached:
            return "Pro Cached"
        case .revoked:
            return "Revoked"
        case .invalid:
            return "Invalid"
        }
    }

    var systemImage: String {
        switch self {
        case .free:
            return "leaf"
        case .proVerified:
            return "checkmark.seal.fill"
        case .proCached:
            return "wifi.slash"
        case .revoked:
            return "xmark.seal.fill"
        case .invalid:
            return "exclamationmark.triangle.fill"
        }
    }
}

enum ProFeature: String, CaseIterable, Codable {
    case futureFeature
}

enum LicenseWarningState: String, Codable {
    case none
    case validationStale

    var title: String {
        switch self {
        case .none:
            return ""
        case .validationStale:
            return "Couldn't re-verify Pro for a while. Charge Cat stays unlocked, but please reconnect when you can."
        }
    }
}

struct LicenseState: Codable, Equatable {
    var status: LicenseStatus
    var lastValidatedAt: Date?
    var lastValidationAttemptAt: Date?
    var nextRetryAt: Date?
    var lastKnownTier: EntitlementTier
    var customerEmail: String?
    var warningState: LicenseWarningState
    var lastErrorMessage: String?

    static let free = LicenseState(
        status: .free,
        lastValidatedAt: nil,
        lastValidationAttemptAt: nil,
        nextRetryAt: nil,
        lastKnownTier: .free,
        customerEmail: nil,
        warningState: .none,
        lastErrorMessage: nil
    )

    var hasProAccess: Bool {
        status.allowsProAccess
    }

    var tier: EntitlementTier {
        hasProAccess ? .pro : .free
    }

    func refreshedWarning(
        now: Date = Date(),
        threshold: TimeInterval = LicensingConfiguration.defaultWarningInterval
    ) -> LicenseState {
        var copy = self
        guard hasProAccess || lastKnownTier == .pro else {
            copy.warningState = .none
            return copy
        }

        guard let lastValidatedAt else {
            copy.warningState = .none
            return copy
        }

        copy.warningState = now.timeIntervalSince(lastValidatedAt) >= threshold ? .validationStale : .none
        return copy
    }
}
