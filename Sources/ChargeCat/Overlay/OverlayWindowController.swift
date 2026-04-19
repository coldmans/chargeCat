import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject, OverlayPresenting {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let bottomPadding: CGFloat = 12
        static let topPadding: CGFloat = 8

        static func panelSize(for asset: OverlayAnimationAsset) -> NSSize {
            let imageSize = asset.overlayDisplaySize
            return NSSize(
                width: imageSize.width + horizontalPadding,
                height: imageSize.height + bottomPadding + topPadding
            )
        }
    }

    private let panel: NSPanel
    private let soundPlayer: SoundPlayer
    private var currentPresentationID = UUID()

    init(soundPlayer: SoundPlayer) {
        self.soundPlayer = soundPlayer
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Layout.panelSize(for: .catDoor)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.orderOut(nil)
    }

    func present(payload: OverlayPayload) {
        let presentationID = UUID()
        currentPresentationID = presentationID
        panel.setContentSize(Layout.panelSize(for: payload.asset))
        panel.contentView = NSHostingView(
            rootView: OverlayContainerView(payload: payload, soundPlayer: soundPlayer) { [weak self] in
                guard let self, self.currentPresentationID == presentationID else { return }
                self.panel.orderOut(nil)
            }
        )
        positionPanel(for: payload.side, asset: payload.asset)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func positionPanel(for side: ScreenSide, asset: OverlayAnimationAsset) {
        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let inset: CGFloat = 18
        let panelSize = Layout.panelSize(for: asset)
        let width = panelSize.width
        let height = panelSize.height

        let x: CGFloat
        switch side {
        case .left:
            x = visibleFrame.minX + inset
        case .right:
            x = visibleFrame.maxX - width - inset
        }

        panel.setFrame(
            NSRect(x: x, y: visibleFrame.minY + inset, width: width, height: height),
            display: true
        )
    }
}
