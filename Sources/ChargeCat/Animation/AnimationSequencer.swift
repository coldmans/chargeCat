import SwiftUI

@MainActor
protocol AnimationSequencing {
    func run(type: AnimationType, payload: OverlayPayload) async
}

struct AnimationSceneValues {
    var doorAngle: Double = -90
    var catTravel: CGFloat = -8
    var bowAngle: Double = 0
    var smileAmount: CGFloat = 0.08
    var mouthOpen: CGFloat = 0
    var squint: CGFloat = 0
    var headTilt: Double = 0
    var bodyScaleY: CGFloat = 1
    var bounce: CGFloat = 6
    var portalGlow: Double = 0.25
    var overlayOpacity: Double = 0
    var sparkleOpacity: Double = 0
    var sparkleScale: CGFloat = 0.8
}

@MainActor
final class AnimationSequencer: AnimationSequencing {
    private var scene: AnimationSceneValues
    private let apply: (AnimationSceneValues, Animation?) -> Void
    private let playSound: (SoundEffect) -> Void
    private let finish: () -> Void

    init(
        initialScene: AnimationSceneValues,
        apply: @escaping (AnimationSceneValues, Animation?) -> Void,
        playSound: @escaping (SoundEffect) -> Void,
        finish: @escaping () -> Void
    ) {
        scene = initialScene
        self.apply = apply
        self.playSound = playSound
        self.finish = finish
    }

    func run(type: AnimationType, payload: OverlayPayload) async {
        update(nil) {
            $0.overlayOpacity = 1
            $0.smileAmount = payload.kind == .fullyCharged ? 0.14 : 0.08
        }

        update(.spring(response: 0.34, dampingFraction: 0.82)) {
            $0.portalGlow = 1
            $0.doorAngle = -68
            $0.bounce = 0
        }
        playSound(.doorCreak)

        try? await Task.sleep(for: .milliseconds(180))

        update(.spring(response: 0.42, dampingFraction: 0.76)) {
            $0.doorAngle = -16
            $0.catTravel = type == .celebrate ? 72 : 66
            $0.bounce = -6
        }

        switch type {
        case .bow:
            await runBow()
        case .stretch:
            await runStretch()
        case .yawn:
            await runYawn()
        case .celebrate:
            await runCelebrate()
        }

        try? await Task.sleep(for: .milliseconds(220))

        update(.interpolatingSpring(stiffness: 180, damping: 14)) {
            $0.catTravel = -8
            $0.doorAngle = -78
            $0.bounce = 4
            $0.sparkleOpacity = 0
            $0.sparkleScale = 0.8
        }

        try? await Task.sleep(for: .milliseconds(220))

        update(.easeIn(duration: 1.22)) {
            $0.overlayOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(250))
        finish()
    }

    private func runBow() async {
        try? await Task.sleep(for: .milliseconds(320))
        playSound(.catChirp)

        update(.easeInOut(duration: 0.5)) {
            $0.bowAngle = 18
            $0.smileAmount = 0.26
            $0.bounce = 0
        }

        try? await Task.sleep(for: .milliseconds(220))

        update(.easeInOut(duration: 0.72)) {
            $0.bowAngle = 0
            $0.bounce = -3
            $0.smileAmount = 0.30
        }

        try? await Task.sleep(for: .milliseconds(280))
    }

    private func runStretch() async {
        try? await Task.sleep(for: .milliseconds(320))
        playSound(.catChirp)

        update(.spring(response: 0.5, dampingFraction: 0.7)) {
            $0.bowAngle = -8
            $0.bounce = -10
            $0.bodyScaleY = 1.15
            $0.smileAmount = 0.24
        }

        try? await Task.sleep(for: .milliseconds(400))

        update(.easeInOut(duration: 0.9)) {
            $0.bowAngle = 0
            $0.bounce = 0
            $0.bodyScaleY = 1
            $0.smileAmount = 0.32
        }
    }

    private func runYawn() async {
        try? await Task.sleep(for: .milliseconds(320))

        update(.easeInOut(duration: 0.5)) {
            $0.bowAngle = 5
            $0.headTilt = 8
            $0.smileAmount = 0.14
        }

        try? await Task.sleep(for: .milliseconds(120))
        playSound(.catChirp)

        update(.easeInOut(duration: 0.7)) {
            $0.mouthOpen = 0.6
            $0.squint = 0.75
        }

        try? await Task.sleep(for: .milliseconds(180))

        update(.easeOut(duration: 1.05)) {
            $0.mouthOpen = 0
            $0.squint = 0
            $0.smileAmount = 0.28
            $0.bowAngle = 0
            $0.headTilt = 0
        }
    }

    private func runCelebrate() async {
        try? await Task.sleep(for: .milliseconds(320))
        playSound(.catChirp)

        update(.spring(response: 0.3, dampingFraction: 0.6)) {
            $0.bounce = -14
            $0.smileAmount = 0.38
        }

        try? await Task.sleep(for: .milliseconds(200))

        update(.spring(response: 0.35, dampingFraction: 0.8)) {
            $0.bounce = 0
        }

        try? await Task.sleep(for: .milliseconds(160))
        playSound(.sparkle)

        update(.easeOut(duration: 0.7)) {
            $0.sparkleOpacity = 1
            $0.sparkleScale = 1.18
        }

        try? await Task.sleep(for: .milliseconds(300))
    }

    private func update(_ animation: Animation?, mutate: (inout AnimationSceneValues) -> Void) {
        mutate(&scene)
        apply(scene, animation)
    }
}
