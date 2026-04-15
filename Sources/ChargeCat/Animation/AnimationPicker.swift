import Foundation

enum AnimationPicker {
    static func selectAnimation(for event: OverlayEventKind) -> AnimationType {
        if event == .fullyCharged {
            return .celebrate
        }

        let roll = Int.random(in: 0..<10)
        switch roll {
        case 0..<5:
            return .bow
        case 5..<8:
            return .stretch
        default:
            return .yawn
        }
    }
}
