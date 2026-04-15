import SwiftUI

struct OverlayContainerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let payload: OverlayPayload
    let soundPlayer: SoundPlayer
    let onFinished: () -> Void

    @State private var overlayOpacity = 0.0
    @State private var blurRadius = 0.0
    @State private var isFinishing = false
    @State private var currentFrameIndex = 0

    private var overlayGIFSize: CGSize {
        GIFAsset.catDoor.overlayDisplaySize
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                if payload.side == .right {
                    Spacer(minLength: 0)
                }

                gifView
                    .frame(width: overlayGIFSize.width, height: overlayGIFSize.height)
                    .scaleEffect(x: payload.side == .left ? 1 : -1, y: 1)
                    .blur(radius: blurRadius)
                    .opacity(overlayOpacity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)

                if payload.side == .left {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
        .background(Color.clear)
        .allowsHitTesting(false)
        .task(id: payload.id) {
            if reduceMotion {
                await runReducedMotion()
            } else {
                await runGIFSequence()
            }
        }
    }

    @MainActor
    private func runGIFSequence() async {
        overlayOpacity = 1
        blurRadius = 0
        isFinishing = false
        currentFrameIndex = 0

        let doorSound = Task { @MainActor in
            try? await Task.sleep(for: GIFAsset.catDoor.doorCreakDelay)
            soundPlayer.play(.doorCreak)
        }

        let chirpSound = Task { @MainActor in
            try? await Task.sleep(for: GIFAsset.catDoor.catChirpDelay)
            soundPlayer.play(.catChirp)
        }

        let sparkleSound = Task { @MainActor in
            guard payload.kind == .fullyCharged else { return }
            try? await Task.sleep(for: GIFAsset.catDoor.sparkleDelay)
            soundPlayer.play(.sparkle)
        }

        for frameIndex in 0..<GIFAsset.catDoor.frameCount {
            currentFrameIndex = frameIndex
            try? await Task.sleep(for: GIFAsset.catDoor.frameDelay(at: frameIndex))
        }

        _ = await (doorSound.value, chirpSound.value, sparkleSound.value)

        isFinishing = true
        currentFrameIndex = GIFAsset.catDoor.lastFrameIndex
        withAnimation(.easeOut(duration: 0.825)) {
            blurRadius = 14
            overlayOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(975))
        onFinished()
    }

    @MainActor
    private func runReducedMotion() async {
        overlayOpacity = 1
        blurRadius = 0
        isFinishing = true
        currentFrameIndex = GIFAsset.catDoor.previewFrame
        try? await Task.sleep(for: .seconds(2))
        withAnimation(.easeOut(duration: 0.3)) {
            blurRadius = 10
            overlayOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(350))
        onFinished()
    }

    @ViewBuilder
    private var gifView: some View {
        GIFAnimationView(
            asset: .catDoor,
            frameIndex: isFinishing ? GIFAsset.catDoor.lastFrameIndex : currentFrameIndex
        )
    }
}
