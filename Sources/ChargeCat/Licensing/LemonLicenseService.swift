import AppKit
import Foundation

@MainActor
final class LemonLicenseService: Licensing {
    private enum Endpoint: String {
        case activate
        case validate
        case deactivate
    }

    struct Snapshot {
        let state: LicenseState
        let customerEmail: String?
        let maskedLicenseKey: String?
        let hasStoredLicense: Bool
    }

    let configuration: LicensingConfiguration

    private let keychain: LicenseKeychainStore
    private let session: URLSession
    private let validationCoordinator: LicenseValidationCoordinator
    private let currentState: () -> LicenseState
    private let currentLanguage: () -> AppLanguage

    init(
        configuration: LicensingConfiguration = .load(),
        keychain: LicenseKeychainStore = LicenseKeychainStore(),
        session: URLSession = .shared,
        validationCoordinator: LicenseValidationCoordinator? = nil,
        currentState: @escaping () -> LicenseState,
        currentLanguage: @escaping () -> AppLanguage = { .korean }
    ) {
        self.configuration = configuration
        self.keychain = keychain
        self.session = session
        self.validationCoordinator = validationCoordinator ?? LicenseValidationCoordinator()
        self.currentState = currentState
        self.currentLanguage = currentLanguage
    }

    private var copy: AppCopy {
        AppCopy(language: currentLanguage())
    }

    func snapshot(allowsAuthenticationUI: Bool) -> Snapshot {
        let interactionPolicy: KeychainInteractionPolicy = allowsAuthenticationUI ? .allowUI : .failIfPromptRequired
        let state = currentState()

        return Snapshot(
            state: state,
            customerEmail: keychain.loadCustomerEmail(interactionPolicy: interactionPolicy) ?? state.customerEmail,
            maskedLicenseKey: keychain.loadMaskedLicenseKey(interactionPolicy: interactionPolicy),
            hasStoredLicense: keychain.hasLicenseKey(interactionPolicy: interactionPolicy) || state.status != .free || state.lastKnownTier == .pro
        )
    }

    func sanitizeInitialState(_ state: LicenseState) -> LicenseState {
        return state.refreshedWarning()
    }

    func activate(licenseKey: String, customerEmail: String?) async throws -> LicenseState {
        let normalizedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if isChargeCatLicenseKey(normalizedKey) {
            return try await activateChargeCatLicense(licenseKey: normalizedKey, customerEmail: customerEmail)
        }

        guard configuration.isLemonConfigured else {
            throw LicensingError.notConfigured
        }

        guard UUID(uuidString: normalizedKey) != nil else {
            throw LicensingError.invalid(
                message: copy.licenseKeyFormatWrong,
                suggestedState: .free
            )
        }

        let installationId = keychain.installationId()
        let request = [
            URLQueryItem(name: "license_key", value: normalizedKey),
            URLQueryItem(name: "instance_name", value: instanceName(for: installationId))
        ]

        let response: LemonActivateResponse
        do {
            response = try await send(endpoint: .activate, formItems: request)
        } catch let error as NetworkFailure {
            if error.isTransient {
                throw LicensingError.transient(message: error.message)
            }

            throw LicensingError.invalid(
                message: error.message,
                suggestedState: .free
            )
        }

        guard response.activated else {
            throw activationFailure(from: response)
        }

        guard let meta = response.meta,
              let licenseKeyObject = response.licenseKey,
              let instance = response.instance
        else {
            throw LicensingError.transient(message: copy.lemonIncompleteActivation)
        }

        if let failureState = explicitFailureState(
            licenseStatus: licenseKeyObject.status,
            meta: meta,
            instance: instance,
            error: response.error,
            customerEmail: response.meta?.customerEmail ?? customerEmail
        ) {
            throw failureState
        }

        let nextState = LicenseState(
            status: .proVerified,
            lastValidatedAt: Date(),
            lastValidationAttemptAt: Date(),
            nextRetryAt: nil,
            lastKnownTier: .pro,
            customerEmail: normalizedEmail(response.meta?.customerEmail ?? customerEmail),
            warningState: .none,
            lastErrorMessage: nil
        )

        keychain.saveActivatedLicense(
            provider: .lemon,
            licenseKey: normalizedKey,
            instanceId: instance.id,
            installationId: installationId,
            customerEmail: nextState.customerEmail
        )

        return nextState
    }

    func validateCachedLicense(
        force: Bool = false,
        allowsAuthenticationUI: Bool = false
    ) async -> LicenseState {
        let interactionPolicy: KeychainInteractionPolicy = allowsAuthenticationUI ? .allowUI : .failIfPromptRequired
        guard let credentials = keychain.loadCredentials(interactionPolicy: interactionPolicy) else {
            return currentState().refreshedWarning()
        }

        let state = currentState()
        return await validationCoordinator.validate(force: force, currentState: state) { [weak self] in
            guard let self else {
                return .transientFailure(message: AppCopy(language: .korean).licenseServiceWentAway, retryAfter: nil)
            }
            if credentials.provider == .chargeCat {
                return await self.performChargeCatValidation(with: credentials)
            }
            return await self.performValidation(with: credentials)
        }
    }

    func deactivateCurrentMac() async throws -> LicenseState {
        guard let credentials = keychain.loadCredentials(),
              let instanceId = credentials.instanceId
        else {
            throw LicensingError.missingStoredLicense
        }

        if credentials.provider == .chargeCat {
            try await deactivateChargeCatLicense(
                licenseKey: credentials.licenseKey,
                instanceId: instanceId
            )
            keychain.clearActivation()
            return .free
        }

        let response: LemonDeactivateResponse
        do {
            response = try await send(
                endpoint: .deactivate,
                formItems: [
                    URLQueryItem(name: "license_key", value: credentials.licenseKey),
                    URLQueryItem(name: "instance_id", value: instanceId)
                ]
            )
        } catch let error as NetworkFailure {
            throw LicensingError.transient(message: error.message)
        }

        guard response.deactivated else {
            throw LicensingError.transient(
                message: response.error ?? copy.lemonCouldNotDeactivateThisMac
            )
        }

        keychain.clearActivation()
        return .free
    }

    func installationID() -> String {
        keychain.installationId()
    }

    func assetDownloadAuthorization(allowsAuthenticationUI: Bool) -> OverlayAssetDownloadAuthorization? {
        let interactionPolicy: KeychainInteractionPolicy = allowsAuthenticationUI ? .allowUI : .failIfPromptRequired
        guard let credentials = keychain.loadCredentials(interactionPolicy: interactionPolicy),
              let instanceId = credentials.instanceId,
              credentials.licenseKey.isEmpty == false,
              instanceId.isEmpty == false
        else {
            return nil
        }

        return OverlayAssetDownloadAuthorization(
            licenseKey: credentials.licenseKey,
            instanceId: instanceId
        )
    }

    var supportsChargeCatBackendLicensing: Bool {
        configuration.backendBaseURL != nil
    }

    func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    private func performValidation(with credentials: StoredLicenseCredentials) async -> ValidationAttemptResult {
        do {
            let response: LemonValidateResponse = try await send(
                endpoint: .validate,
                formItems: [
                    URLQueryItem(name: "license_key", value: credentials.licenseKey),
                    URLQueryItem(name: "instance_id", value: credentials.instanceId)
                ].compactMap { item in
                    item.value == nil ? nil : item
                }
            )

            guard response.valid else {
                if let explicitFailure = explicitValidationFailure(from: response) {
                    return .explicitFailure(explicitFailure)
                }

                return .transientFailure(
                    message: response.error ?? copy.lemonCouldNotVerifyLicense,
                    retryAfter: nil
                )
            }

            guard let licenseKeyObject = response.licenseKey,
                  let meta = response.meta
            else {
                return .transientFailure(
                    message: copy.lemonIncompleteValidation,
                    retryAfter: nil
                )
            }

            if let failure = explicitFailureState(
                licenseStatus: licenseKeyObject.status,
                meta: meta,
                instance: response.instance,
                error: response.error,
                customerEmail: response.meta?.customerEmail ?? credentials.customerEmail,
                expectedInstanceId: credentials.instanceId
            ) {
                switch failure {
                case let .invalid(_, suggestedState):
                    return .explicitFailure(suggestedState)
                case let .revoked(_, suggestedState):
                    return .explicitFailure(suggestedState)
                case .notConfigured, .missingStoredLicense, .transient:
                    break
                }
            }

            return .success(
                LicenseState(
                    status: .proVerified,
                    lastValidatedAt: Date(),
                    lastValidationAttemptAt: Date(),
                    nextRetryAt: nil,
                    lastKnownTier: .pro,
                    customerEmail: normalizedEmail(response.meta?.customerEmail ?? credentials.customerEmail),
                    warningState: .none,
                    lastErrorMessage: nil
                )
            )
        } catch let error as NetworkFailure {
            if error.isTransient == false {
                return .explicitFailure(
                    explicitDowngradedState(
                        status: .invalid,
                        customerEmail: credentials.customerEmail,
                        message: error.message
                    )
                )
            }

            return .transientFailure(message: error.message, retryAfter: error.retryAfter)
        } catch {
            return .transientFailure(
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                retryAfter: nil
            )
        }
    }

    private func activateChargeCatLicense(
        licenseKey: String,
        customerEmail: String?
    ) async throws -> LicenseState {
        guard let url = backendLicensingURL(path: "activate") else {
            throw LicensingError.notConfigured
        }

        let installationId = keychain.installationId()
        let response: BackendLicenseActivationResponse
        do {
            response = try await sendBackend(
                url: url,
                requestBody: BackendLicenseActivationRequest(
                    licenseKey: licenseKey,
                    installationId: installationId,
                    instanceName: instanceName(for: installationId),
                    customerEmail: normalizedEmail(customerEmail)
                )
            )
        } catch let error as NetworkFailure {
            if error.isTransient {
                throw LicensingError.transient(message: error.message)
            }

            throw LicensingError.invalid(
                message: error.message,
                suggestedState: .free
            )
        }

        guard response.activated, let instance = response.instance else {
            throw backendActivationFailure(from: response)
        }

        let nextState = LicenseState(
            status: .proVerified,
            lastValidatedAt: Date(),
            lastValidationAttemptAt: Date(),
            nextRetryAt: nil,
            lastKnownTier: .pro,
            customerEmail: normalizedEmail(response.customerEmail ?? customerEmail),
            warningState: .none,
            lastErrorMessage: nil
        )

        keychain.saveActivatedLicense(
            provider: .chargeCat,
            licenseKey: licenseKey,
            instanceId: instance.id,
            installationId: installationId,
            customerEmail: nextState.customerEmail
        )

        return nextState
    }

    private func performChargeCatValidation(with credentials: StoredLicenseCredentials) async -> ValidationAttemptResult {
        guard let url = backendLicensingURL(path: "validate") else {
            return .transientFailure(message: copy.checkoutBackendUnavailable, retryAfter: nil)
        }

        do {
            let response: BackendLicenseValidationResponse = try await sendBackend(
                url: url,
                requestBody: BackendLicenseValidationRequest(
                    licenseKey: credentials.licenseKey,
                    instanceId: credentials.instanceId
                )
            )

            guard response.valid else {
                if let explicitFailure = explicitChargeCatValidationFailure(from: response) {
                    return .explicitFailure(explicitFailure)
                }

                return .transientFailure(
                    message: response.error ?? copy.lemonCouldNotVerifyLicense,
                    retryAfter: nil
                )
            }

            return .success(
                LicenseState(
                    status: .proVerified,
                    lastValidatedAt: Date(),
                    lastValidationAttemptAt: Date(),
                    nextRetryAt: nil,
                    lastKnownTier: .pro,
                    customerEmail: normalizedEmail(response.customerEmail ?? credentials.customerEmail),
                    warningState: .none,
                    lastErrorMessage: nil
                )
            )
        } catch let error as NetworkFailure {
            if error.isTransient == false {
                return .explicitFailure(
                    explicitDowngradedState(
                        status: .invalid,
                        customerEmail: credentials.customerEmail,
                        message: error.message
                    )
                )
            }
            return .transientFailure(message: error.message, retryAfter: error.retryAfter)
        } catch {
            return .transientFailure(
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                retryAfter: nil
            )
        }
    }

    private func deactivateChargeCatLicense(
        licenseKey: String,
        instanceId: String
    ) async throws {
        guard let url = backendLicensingURL(path: "deactivate") else {
            throw LicensingError.notConfigured
        }

        let response: BackendLicenseDeactivationResponse
        do {
            response = try await sendBackend(
                url: url,
                requestBody: BackendLicenseDeactivationRequest(
                    licenseKey: licenseKey,
                    instanceId: instanceId
                )
            )
        } catch let error as NetworkFailure {
            throw LicensingError.transient(message: error.message)
        }

        guard response.deactivated else {
            throw LicensingError.transient(
                message: response.error ?? copy.lemonCouldNotDeactivateThisMac
            )
        }
    }

    private func activationFailure(from response: LemonActivateResponse) -> LicensingError {
        if let failure = explicitFailureState(
            licenseStatus: response.licenseKey?.status,
            meta: response.meta,
            instance: response.instance,
            error: response.error,
            customerEmail: response.meta?.customerEmail
        ) {
            return failure
        }

        let message = response.error ?? copy.activationRejected
        return .invalid(message: message, suggestedState: .free)
    }

    private func backendActivationFailure(from response: BackendLicenseActivationResponse) -> LicensingError {
        if response.license?.status == "revoked" {
            return .revoked(
                message: response.error ?? copy.proLicenseNoLongerActive,
                suggestedState: explicitDowngradedState(
                    status: .revoked,
                    customerEmail: response.customerEmail,
                    message: response.error
                )
            )
        }

        return .invalid(
            message: response.error ?? copy.activationRejected,
            suggestedState: explicitDowngradedState(
                status: .invalid,
                customerEmail: response.customerEmail,
                message: response.error
            )
        )
    }

    private func explicitValidationFailure(from response: LemonValidateResponse) -> LicenseState? {
        if let licenseStatus = response.licenseKey?.status {
            if licenseStatus == "disabled" || licenseStatus == "expired" {
                return explicitDowngradedState(
                    status: .revoked,
                    customerEmail: response.meta?.customerEmail,
                    message: response.error ?? copy.proLicenseNoLongerValid
                )
            }
        }

        let normalized = response.error?.lowercased() ?? ""
        if normalized.contains("not found") || normalized.contains("does not exist") || normalized.contains("invalid") {
            return explicitDowngradedState(
                status: .invalid,
                customerEmail: response.meta?.customerEmail,
                message: response.error ?? copy.proLicenseCouldNotBeFound
            )
        }

        return nil
    }

    private func explicitChargeCatValidationFailure(from response: BackendLicenseValidationResponse) -> LicenseState? {
        if response.license?.status == "revoked" {
            return explicitDowngradedState(
                status: .revoked,
                customerEmail: response.customerEmail,
                message: response.error ?? copy.proLicenseNoLongerValid
            )
        }

        let normalized = response.error?.lowercased() ?? ""
        if normalized.contains("saved activation") ||
            normalized.contains("this mac") ||
            normalized.contains("no longer valid") ||
            normalized.contains("deactivated") ||
            normalized.contains("instance") {
            return explicitDowngradedState(
                status: .revoked,
                customerEmail: response.customerEmail,
                message: response.error ?? copy.savedActivationMissing
            )
        }

        if normalized.contains("not found") || normalized.contains("invalid") || normalized.contains("activation limit") {
            return explicitDowngradedState(
                status: .invalid,
                customerEmail: response.customerEmail,
                message: response.error ?? copy.proLicenseCouldNotBeFound
            )
        }

        return nil
    }

    private func explicitFailureState(
        licenseStatus: String?,
        meta: LemonLicenseMeta?,
        instance: LemonLicenseInstance?,
        error: String?,
        customerEmail: String?,
        expectedInstanceId: String? = nil
    ) -> LicensingError? {
        if let licenseStatus, licenseStatus == "disabled" || licenseStatus == "expired" {
            return .revoked(
                message: error ?? copy.proLicenseNoLongerActive,
                suggestedState: explicitDowngradedState(
                    status: .revoked,
                    customerEmail: customerEmail,
                    message: error
                )
            )
        }

        if let meta {
            if meta.storeID != configuration.storeID ||
                meta.productID != configuration.productID ||
                meta.variantID != configuration.variantID {
                return .revoked(
                    message: copy.differentLemonProduct,
                    suggestedState: explicitDowngradedState(
                        status: .revoked,
                        customerEmail: customerEmail,
                        message: copy.differentProduct
                    )
                )
            }
        }

        if let expectedInstanceId,
           let instance,
           instance.id != expectedInstanceId {
            return .revoked(
                message: copy.savedActivationMismatch,
                suggestedState: explicitDowngradedState(
                    status: .revoked,
                    customerEmail: customerEmail,
                    message: copy.savedActivationMismatch
                )
            )
        }

        if let expectedInstanceId, expectedInstanceId.isEmpty == false, instance == nil {
            return .revoked(
                message: copy.savedActivationMissing,
                suggestedState: explicitDowngradedState(
                    status: .revoked,
                    customerEmail: customerEmail,
                    message: copy.savedActivationMissing
                )
            )
        }

        let normalized = error?.lowercased() ?? ""
        if normalized.contains("activation limit") ||
            normalized.contains("not found") ||
            normalized.contains("does not exist") ||
            normalized.contains("missing") ||
            normalized.contains("required") ||
            normalized.contains("invalid") {
            return .invalid(
                message: error ?? copy.licenseKeyInvalidForActivation,
                suggestedState: explicitDowngradedState(
                    status: .invalid,
                    customerEmail: customerEmail,
                    message: error
                )
            )
        }

        return nil
    }

    private func explicitDowngradedState(
        status: LicenseStatus,
        customerEmail: String?,
        message: String?
    ) -> LicenseState {
        LicenseState(
            status: status,
            lastValidatedAt: nil,
            lastValidationAttemptAt: Date(),
            nextRetryAt: nil,
            lastKnownTier: .free,
            customerEmail: normalizedEmail(customerEmail),
            warningState: .none,
            lastErrorMessage: message
        )
    }

    private func normalizedEmail(_ email: String?) -> String? {
        guard let email else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func instanceName(for installationId: String) -> String {
        let shortID = String(installationId.prefix(8))
        let hostName = Host.current().localizedName ?? Host.current().name ?? "Mac"
        let sanitizedHost = hostName
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return "ChargeCat-\(sanitizedHost.isEmpty ? "Mac" : sanitizedHost)-\(shortID)"
    }

    private func backendLicensingURL(path: String) -> URL? {
        configuration.backendBaseURL?
            .appendingPathComponent("api")
            .appendingPathComponent("licenses")
            .appendingPathComponent(path)
    }

    private func isChargeCatLicenseKey(_ key: String) -> Bool {
        key.hasPrefix("ccp_")
    }

    private func send<Response: Decodable>(
        endpoint: Endpoint,
        formItems: [URLQueryItem]
    ) async throws -> Response {
        let body = formItems
            .map { item in
                let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
                let name = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.name
                let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
                return "\(name)=\(value)"
            }
            .joined(separator: "&")

        var request = URLRequest(url: LicensingConfiguration.lemonBaseURL.appendingPathComponent(endpoint.rawValue))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkFailure(
                    message: copy.invalidNetworkResponse,
                    retryAfter: nil,
                    isTransient: true
                )
            }

            if httpResponse.statusCode == 429 {
                throw NetworkFailure(
                    message: copy.rateLimitedRetrySoon,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: true
                )
            }

            if (500...599).contains(httpResponse.statusCode) {
                throw NetworkFailure(
                    message: copy.lemonHavingMoment,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: true
                )
            }

            if (400...499).contains(httpResponse.statusCode) {
                let apiError = try? JSONDecoder().decode(LemonErrorResponse.self, from: data)
                throw NetworkFailure(
                    message: apiError?.error ?? copy.lemonRejectedRequest,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: false
                )
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch let error as NetworkFailure {
            throw error
        } catch {
            throw NetworkFailure(
                message: copy.couldntReachLemon,
                retryAfter: nil,
                isTransient: true
            )
        }
    }

    private func sendBackend<RequestBody: Encodable, Response: Decodable>(
        url: URL,
        requestBody: RequestBody
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkFailure(
                    message: copy.invalidNetworkResponse,
                    retryAfter: nil,
                    isTransient: true
                )
            }

            if httpResponse.statusCode == 429 {
                throw NetworkFailure(
                    message: copy.rateLimitedRetrySoon,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: true
                )
            }

            if (500 ... 599).contains(httpResponse.statusCode) {
                throw NetworkFailure(
                    message: copy.lemonHavingMoment,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: true
                )
            }

            if (400 ... 499).contains(httpResponse.statusCode) {
                let apiError = try? JSONDecoder().decode(LemonErrorResponse.self, from: data)
                throw NetworkFailure(
                    message: apiError?.error ?? copy.checkoutBackendUnavailable,
                    retryAfter: retryAfter(from: httpResponse),
                    isTransient: false
                )
            }

            let decoder = JSONDecoder()
            return try decoder.decode(Response.self, from: data)
        } catch let error as NetworkFailure {
            throw error
        } catch {
            throw NetworkFailure(
                message: copy.checkoutBackendUnavailable,
                retryAfter: nil,
                isTransient: true
            )
        }
    }

    private func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let rawValue = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(rawValue)
        else {
            return nil
        }
        return seconds
    }
}

private struct LemonErrorResponse: Decodable {
    let error: String
}

private struct LemonActivateResponse: Decodable {
    let activated: Bool
    let error: String?
    let licenseKey: LemonLicenseKey?
    let instance: LemonLicenseInstance?
    let meta: LemonLicenseMeta?
}

private struct LemonValidateResponse: Decodable {
    let valid: Bool
    let error: String?
    let licenseKey: LemonLicenseKey?
    let instance: LemonLicenseInstance?
    let meta: LemonLicenseMeta?
}

private struct LemonDeactivateResponse: Decodable {
    let deactivated: Bool
    let error: String?
}

private struct BackendLicenseActivationRequest: Encodable {
    let licenseKey: String
    let installationId: String
    let instanceName: String
    let customerEmail: String?
}

private struct BackendLicenseValidationRequest: Encodable {
    let licenseKey: String
    let instanceId: String?
}

private struct BackendLicenseDeactivationRequest: Encodable {
    let licenseKey: String
    let instanceId: String
}

private struct BackendLicenseActivationResponse: Decodable {
    let activated: Bool
    let error: String?
    let license: BackendLicensePayload?
    let instance: BackendLicenseInstance?
    let customerEmail: String?
}

private struct BackendLicenseValidationResponse: Decodable {
    let valid: Bool
    let error: String?
    let license: BackendLicensePayload?
    let instance: BackendLicenseInstance?
    let customerEmail: String?
}

private struct BackendLicenseDeactivationResponse: Decodable {
    let deactivated: Bool
    let error: String?
}

private struct BackendLicensePayload: Decodable {
    let key: String
    let status: String
    let activationLimit: Int
    let activationUsage: Int
}

private struct BackendLicenseInstance: Decodable {
    let id: String
    let name: String
}

private struct LemonLicenseKey: Decodable {
    let id: Int
    let status: String
    let key: String
    let activationLimit: Int
    let activationUsage: Int
    let createdAt: String?
    let expiresAt: String?
}

private struct LemonLicenseInstance: Decodable {
    let id: String
    let name: String
    let createdAt: String?
}

private struct LemonLicenseMeta: Decodable {
    let storeID: Int
    let productID: Int
    let variantID: Int
    let customerEmail: String?
}

private struct NetworkFailure: Error {
    let message: String
    let retryAfter: TimeInterval?
    let isTransient: Bool
}
