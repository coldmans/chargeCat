import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    init(model: AppModel, onStart: @escaping () -> Void) {
        let hostingView = NSHostingView(
            rootView: OnboardingView(model: model, onStart: onStart)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Charge Cat"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hostingView
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
