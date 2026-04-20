import Foundation

enum OverlayAssetSource: String, Codable {
    case bundled
    case downloaded
}

struct OverlayAssetReference: Codable, Hashable, Identifiable {
    let source: OverlayAssetSource
    let value: String

    var id: String {
        "\(source.rawValue):\(value)"
    }

    static func bundled(_ asset: OverlayAnimationAsset) -> OverlayAssetReference {
        OverlayAssetReference(source: .bundled, value: asset.rawValue)
    }

    var bundledAsset: OverlayAnimationAsset? {
        guard source == .bundled else { return nil }
        return OverlayAnimationAsset(rawValue: value)
    }
}

extension OverlayEventKind {
    var defaultAssetReference: OverlayAssetReference {
        switch self {
        case .chargeStarted:
            return .bundled(.catDoor)
        case .fullyCharged:
            return .bundled(.fullBelly)
        }
    }
}
