import Foundation

struct LicensingConfiguration: Decodable {
    static let defaultValidationInterval: TimeInterval = 7 * 24 * 60 * 60
    static let defaultWarningInterval: TimeInterval = 60 * 24 * 60 * 60
    static let keychainService = "com.coldmans.charge-cat.license"
    static let lemonBaseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses")!
    static let appURLScheme = "chargecat"

    let storeID: Int
    let productID: Int
    let variantID: Int
    let checkoutURL: URL?
    let backendBaseURL: URL?
    let myOrdersURL: URL
    let supportURL: URL
    let productName: String
    let variantName: String

    init(
        storeID: Int,
        productID: Int,
        variantID: Int,
        checkoutURL: URL?,
        backendBaseURL: URL?,
        myOrdersURL: URL,
        supportURL: URL,
        productName: String,
        variantName: String
    ) {
        self.storeID = storeID
        self.productID = productID
        self.variantID = variantID
        self.checkoutURL = checkoutURL
        self.backendBaseURL = backendBaseURL
        self.myOrdersURL = myOrdersURL
        self.supportURL = supportURL
        self.productName = productName
        self.variantName = variantName
    }

    var hasCheckoutEntryPoint: Bool {
        checkoutURL != nil || backendBaseURL != nil
    }

    var isConfigured: Bool {
        hasCheckoutEntryPoint
    }

    var isLemonConfigured: Bool {
        storeID > 0 && productID > 0 && variantID > 0
    }

    var checkoutSessionsURL: URL? {
        backendBaseURL?.appendingPathComponent("api/checkout-sessions")
    }

    var backendBuyURL: URL? {
        backendBaseURL?.appendingPathComponent("buy/pro")
    }

    static func load(bundle: Bundle = ResourceBundle.current) -> LicensingConfiguration {
        guard let url = bundle.url(forResource: "licensing-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(LicensingConfiguration.self, from: data)
        else {
            return .fallback
        }
        return config
    }

    init(from decoder: any Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case storeID
            case productID
            case variantID
            case checkoutURL
            case backendBaseURL
            case myOrdersURL
            case supportURL
            case productName
            case variantName
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        storeID = try container.decodeIfPresent(Int.self, forKey: .storeID) ?? 0
        productID = try container.decodeIfPresent(Int.self, forKey: .productID) ?? 0
        variantID = try container.decodeIfPresent(Int.self, forKey: .variantID) ?? 0
        checkoutURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .checkoutURL))
        backendBaseURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .backendBaseURL))
        myOrdersURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .myOrdersURL))
            ?? URL(string: "https://app.lemonsqueezy.com/my-orders")!
        supportURL = Self.optionalURL(from: try container.decodeIfPresent(String.self, forKey: .supportURL))
            ?? URL(string: "https://github.com/coldmans/chargeCat/issues")!
        productName = try container.decodeIfPresent(String.self, forKey: .productName) ?? "Charge Cat Pro"
        variantName = try container.decodeIfPresent(String.self, forKey: .variantName) ?? "Lifetime"
    }

    private static func optionalURL(from value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return URL(string: trimmed)
    }

    private static let fallback = LicensingConfiguration(
        storeID: 0,
        productID: 0,
        variantID: 0,
        checkoutURL: nil,
        backendBaseURL: nil,
        myOrdersURL: URL(string: "https://app.lemonsqueezy.com/my-orders")!,
        supportURL: URL(string: "https://github.com/coldmans/chargeCat/issues")!,
        productName: "Charge Cat Pro",
        variantName: "Lifetime"
    )
}
