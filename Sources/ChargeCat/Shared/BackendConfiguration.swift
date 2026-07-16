import Foundation

struct BackendConfiguration: Decodable {
    let backendBaseURL: URL?
    let assetCatalogURLOverride: URL?
    let supportURL: URL
    let privacyPolicyURL: URL

    init(
        backendBaseURL: URL?,
        assetCatalogURLOverride: URL?,
        supportURL: URL,
        privacyPolicyURL: URL
    ) {
        self.backendBaseURL = backendBaseURL
        self.assetCatalogURLOverride = assetCatalogURLOverride
        self.supportURL = supportURL
        self.privacyPolicyURL = privacyPolicyURL
    }

    var assetCatalogURL: URL? {
        assetCatalogURLOverride ?? backendBaseURL?.appendingPathComponent("api/assets/catalog")
    }

    static func load(bundle: Bundle = ResourceBundle.current) -> BackendConfiguration {
        guard let url = bundle.url(forResource: "backend-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(BackendConfiguration.self, from: data)
        else {
            return .fallback
        }
        return config
    }

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case backendBaseURL
            case assetCatalogURL
            case supportURL
            case privacyPolicyURL
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        backendBaseURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .backendBaseURL))
        assetCatalogURLOverride = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .assetCatalogURL))
        supportURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .supportURL))
            ?? URL(string: "https://github.com/coldmans/chargeCat/issues")!
        privacyPolicyURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .privacyPolicyURL))
            ?? URL(string: "https://coldmans.github.io/chargeCat/privacy.html")!
    }

    private static func optionalURL(from value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return URL(string: trimmed)
    }

    private static let fallback = BackendConfiguration(
        backendBaseURL: nil,
        assetCatalogURLOverride: nil,
        supportURL: URL(string: "https://github.com/coldmans/chargeCat/issues")!,
        privacyPolicyURL: URL(string: "https://coldmans.github.io/chargeCat/privacy.html")!
    )
}
