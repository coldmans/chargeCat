import CoreGraphics

enum CatCondition {
    case low
    case regular
    case full

    static func from(level: Int, event: OverlayEventKind) -> Self {
        if event == .fullyCharged || level >= 80 {
            return .full
        }
        if level <= 20 {
            return .low
        }
        return .regular
    }

    var bodySize: CGSize {
        switch self {
        case .low:
            return CGSize(width: 56, height: 44)
        case .regular:
            return CGSize(width: 68, height: 52)
        case .full:
            return CGSize(width: 78, height: 62)
        }
    }

    var headSize: CGFloat {
        switch self {
        case .low:
            return 34
        case .regular:
            return 38
        case .full:
            return 40
        }
    }

    var earLift: CGFloat {
        switch self {
        case .low:
            return -2
        case .regular:
            return 0
        case .full:
            return 2
        }
    }
}
