import Foundation

enum OverlayEventKind: String {
    case chargeStarted
    case fullyCharged

    var title: String {
        switch self {
        case .chargeStarted:
            return "Charge Start"
        case .fullyCharged:
            return "Fully Charged"
        }
    }
}

struct OverlayPayload: Identifiable, Equatable {
    let id: UUID
    let kind: OverlayEventKind
    let batteryLevel: Int
    let side: ScreenSide
    let animationType: AnimationType

    var condition: CatCondition {
        CatCondition.from(level: batteryLevel, event: kind)
    }
}

@MainActor
protocol OverlayPresenting: AnyObject {
    func present(payload: OverlayPayload)
}
