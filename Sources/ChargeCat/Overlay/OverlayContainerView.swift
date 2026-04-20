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

    private var overlayMediaSize: CGSize {
        payload.asset.overlayDisplaySize
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                if payload.side == .right {
                    Spacer(minLength: 0)
                }

                gifView
                    .frame(width: overlayMediaSize.width, height: overlayMediaSize.height)
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
            } else if let gifAsset = payload.asset.gifAsset {
                await runGIFSequence(asset: gifAsset)
            } else {
                await runVideoSequence()
            }
        }
    }

    @MainActor
    private func runGIFSequence(asset: GIFAsset) async {
        overlayOpacity = 1
        blurRadius = 0
        isFinishing = false
        currentFrameIndex = 0
        let shouldPlaySounds = payload.asset.doorCreakDelay != nil || payload.asset.catChirpDelay != nil

        let doorSound = Task { @MainActor in
            guard shouldPlaySounds, let delay = payload.asset.doorCreakDelay else { return }
            guard await sleepUnlessCancelled(for: delay) else { return }
            soundPlayer.play(.doorCreak)
        }

        let chirpSound = Task { @MainActor in
            guard shouldPlaySounds, let delay = payload.asset.catChirpDelay else { return }
            guard await sleepUnlessCancelled(for: delay) else { return }
            soundPlayer.play(.catChirp)
        }

        let sparkleSound = Task { @MainActor in
            guard payload.asset.bundledAsset == .catDoor, payload.kind == .fullyCharged else { return }
            guard await sleepUnlessCancelled(for: asset.sparkleDelay) else { return }
            soundPlayer.play(.sparkle)
        }

        for frameIndex in 0..<asset.frameCount {
            guard Task.isCancelled == false else {
                cancel(tasks: [doorSound, chirpSound, sparkleSound])
                return
            }
            currentFrameIndex = frameIndex
            guard await sleepUnlessCancelled(for: asset.frameDelay(at: frameIndex)) else {
                cancel(tasks: [doorSound, chirpSound, sparkleSound])
                return
            }
        }

        _ = await (doorSound.value, chirpSound.value, sparkleSound.value)
        guard Task.isCancelled == false else { return }

        isFinishing = true
        currentFrameIndex = asset.lastFrameIndex
        withAnimation(.easeOut(duration: 0.825)) {
            blurRadius = 14
            overlayOpacity = 0
        }
        guard await sleepUnlessCancelled(for: .milliseconds(975)) else { return }
        onFinished()
    }

    @MainActor
    private func runReducedMotion() async {
        overlayOpacity = 1
        blurRadius = 0
        isFinishing = true
        currentFrameIndex = payload.asset.gifAsset?.previewFrame ?? 0
        guard await sleepUnlessCancelled(for: .seconds(2)) else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            blurRadius = 10
            overlayOpacity = 0
        }
        guard await sleepUnlessCancelled(for: .milliseconds(350)) else { return }
        onFinished()
    }

    @MainActor
    private func runVideoSequence() async {
        overlayOpacity = 1
        blurRadius = 0
        isFinishing = false

        let doorSound = Task { @MainActor in
            guard let delay = payload.asset.doorCreakDelay else { return }
            guard await sleepUnlessCancelled(for: delay) else { return }
            soundPlayer.play(.doorCreak)
        }

        let chirpSound = Task { @MainActor in
            guard let delay = payload.asset.catChirpDelay else { return }
            guard await sleepUnlessCancelled(for: delay) else { return }
            soundPlayer.play(.catChirp)
        }

        guard await sleepUnlessCancelled(for: payload.asset.dismissDelay) else { return }
        _ = await (doorSound.value, chirpSound.value)

        isFinishing = true
        withAnimation(.easeOut(duration: 0.45)) {
            blurRadius = 12
            overlayOpacity = 0
        }
        guard await sleepUnlessCancelled(for: .milliseconds(500)) else { return }
        onFinished()
    }

    @MainActor
    private func sleepUnlessCancelled(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return Task.isCancelled == false
        } catch {
            return false
        }
    }

    @MainActor
    private func cancel(tasks: [Task<Void, Never>]) {
        tasks.forEach { $0.cancel() }
    }

    @ViewBuilder
    private var gifView: some View {
        if reduceMotion, let image = payload.asset.previewImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let gifAsset = payload.asset.gifAsset {
            GIFAnimationView(
                asset: gifAsset,
                frameIndex: isFinishing ? gifAsset.lastFrameIndex : currentFrameIndex
            )
        } else if let videoAsset = payload.asset.videoAsset {
            VideoAnimationView(
                asset: videoAsset,
                loop: false,
                isMuted: true,
                playbackID: payload.id.uuidString
            )
        }
    }
}
