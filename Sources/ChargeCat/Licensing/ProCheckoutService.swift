import Foundation

enum ProCheckoutSessionStatus: String, Decodable {
    case pending
    case ready
    case claimed
    case expired
    case failed
}

struct ProCheckoutSession: Decodable {
    let sessionID: String
    let status: ProCheckoutSessionStatus
    let checkoutURL: URL?
    let customerEmail: String?
    let licenseKey: String?
    let expiresAt: Date?
    let completedAt: Date?
    let claimedAt: Date?
    let lastError: String?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case status
        case checkoutURL
        case customerEmail
        case licenseKey
        case expiresAt
        case completedAt
        case claimedAt
        case lastError
    }
}

enum ProCheckoutError: LocalizedError {
    case notConfigured
    case invalidResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Backend checkout is not configured."
        case .invalidResponse:
            return "The checkout backend returned an unexpected response."
        case let .server(message):
            return message
        }
    }
}

actor ProCheckoutService {
    private struct CreateCheckoutRequest: Encodable {
        let installationId: String
        let customerEmail: String?
        let source: String
        let appVersion: String?
    }

    private struct ClaimCheckoutRequest: Encodable {
        let installationId: String
    }

    private struct APIErrorPayload: Decodable {
        let error: String?
    }

    private let configuration: LicensingConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        configuration: LicensingConfiguration = .load(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
    }

    func createCheckoutSession(
        installationId: String,
        customerEmail: String?,
        appVersion: String?
    ) async throws -> ProCheckoutSession {
        guard let url = configuration.checkoutSessionsURL else {
            throw ProCheckoutError.notConfigured
        }

        let request = CreateCheckoutRequest(
            installationId: installationId,
            customerEmail: normalizedEmail(customerEmail),
            source: "app",
            appVersion: appVersion
        )

        return try await send(requestBody: request, to: url, method: "POST")
    }

    func fetchCheckoutSession(
        id: String,
        installationId: String
    ) async throws -> ProCheckoutSession {
        guard let baseURL = configuration.checkoutSessionsURL else {
            throw ProCheckoutError.notConfigured
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(id), resolvingAgainstBaseURL: false) else {
            throw ProCheckoutError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "installationId", value: installationId)
        ]
        guard let url = components.url else {
            throw ProCheckoutError.invalidResponse
        }

        return try await send(requestBody: Optional<ClaimCheckoutRequest>.none, to: url, method: "GET")
    }

    func claimCheckoutSession(
        id: String,
        installationId: String
    ) async throws -> ProCheckoutSession {
        guard let baseURL = configuration.checkoutSessionsURL else {
            throw ProCheckoutError.notConfigured
        }

        return try await send(
            requestBody: ClaimCheckoutRequest(installationId: installationId),
            to: baseURL.appendingPathComponent(id).appendingPathComponent("claim"),
            method: "POST"
        )
    }

    private func send<RequestBody: Encodable>(
        requestBody: RequestBody?,
        to url: URL,
        method: String
    ) async throws -> ProCheckoutSession {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let requestBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(requestBody)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProCheckoutError.invalidResponse
        }

        if (200 ..< 300).contains(httpResponse.statusCode) == false {
            let errorPayload = try? decoder.decode(APIErrorPayload.self, from: data)
            throw ProCheckoutError.server(
                message: errorPayload?.error ?? "Checkout backend error (\(httpResponse.statusCode))."
            )
        }

        guard let session = try? decoder.decode(ProCheckoutSession.self, from: data) else {
            throw ProCheckoutError.invalidResponse
        }

        return session
    }

    private func normalizedEmail(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }
}
