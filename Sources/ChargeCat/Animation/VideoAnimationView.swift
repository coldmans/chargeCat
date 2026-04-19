import AVFoundation
import AppKit
import SwiftUI

struct VideoAnimationView: NSViewRepresentable {
    let asset: VideoAsset
    let loop: Bool
    let isMuted: Bool
    let playbackID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = context.coordinator.player
        context.coordinator.configure(
            asset: asset,
            loop: loop,
            isMuted: isMuted,
            playbackID: playbackID
        )
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.playerLayer.player = context.coordinator.player
        context.coordinator.configure(
            asset: asset,
            loop: loop,
            isMuted: isMuted,
            playbackID: playbackID
        )
    }

    static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.stop()
        nsView.playerLayer.player = nil
    }

    final class Coordinator: @unchecked Sendable {
        let player = AVPlayer()

        private var currentResourceKey: String?
        private var currentPlaybackID: String?
        private var endObserver: NSObjectProtocol?

        func configure(
            asset: VideoAsset,
            loop: Bool,
            isMuted: Bool,
            playbackID: String
        ) {
            player.isMuted = isMuted

            if currentResourceKey != asset.resourceKey {
                currentResourceKey = asset.resourceKey
                currentPlaybackID = nil
                player.replaceCurrentItem(with: asset.playerItem)
            }

            updateLoopObserver(loop: loop)

            if currentPlaybackID != playbackID {
                currentPlaybackID = playbackID
                player.seek(to: .zero)
                player.play()
            } else if loop && player.rate == 0 {
                player.play()
            }
        }

        func stop() {
            removeLoopObserver()
            player.pause()
        }

        deinit {
            removeLoopObserver()
        }

        private func updateLoopObserver(loop: Bool) {
            removeLoopObserver()

            guard loop, let item = player.currentItem else { return }

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }

        private func removeLoopObserver() {
            guard let endObserver else { return }
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}

final class PlayerContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing layer")
        }
        return layer
    }
}
