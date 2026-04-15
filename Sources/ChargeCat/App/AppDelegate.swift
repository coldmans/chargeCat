import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private lazy var batteryMonitor = BatteryMonitor(model: model)
    private var controlWindowController: ControlWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var overlayWindowController: OverlayWindowController?
    private var statusItem: NSStatusItem?
    private var batteryStatusMenuItem: NSMenuItem?
    private var powerModeMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayWindowController = OverlayWindowController(soundPlayer: model.soundPlayer)
        if let overlayWindowController {
            model.bind(overlayPresenter: overlayWindowController)
        }

        NSApp.applicationIconImage = AssetImage.appIcon
        model.onMenuBarStateChanged = { [weak self] in
            self?.updateStatusItem()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateDidChange),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        configureStatusItem()
        batteryMonitor.start()
        presentInitialWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        batteryMonitor.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func openSettings() {
        if controlWindowController == nil {
            controlWindowController = ControlWindowController(model: model)
        }

        onboardingWindowController?.close()
        controlWindowController?.showWindow(nil)
        controlWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func playPreviewAnimation() {
        model.trigger(.chargeStarted, source: "menu bar preview")
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc
    private func handlePowerStateDidChange() {
        model.refreshPowerMode()
    }

    private func presentInitialWindow() {
        guard UserSettings.hasCompletedOnboarding == false else {
            openSettings()
            return
        }

        onboardingWindowController = OnboardingWindowController(model: model) { [weak self] in
            UserSettings.hasCompletedOnboarding = true
            self?.openSettings()
        }

        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.center()
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = AssetImage.menuBar(for: model.latestBattery)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        statusItem.button?.toolTip = "Charge Cat"

        let menu = NSMenu()
        let batteryStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        batteryStatusMenuItem.isEnabled = false
        let powerModeMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        powerModeMenuItem.isEnabled = false
        menu.addItem(batteryStatusMenuItem)
        menu.addItem(powerModeMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Preview Animation", action: #selector(playPreviewAnimation), keyEquivalent: "p"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        self.statusItem = statusItem
        self.batteryStatusMenuItem = batteryStatusMenuItem
        self.powerModeMenuItem = powerModeMenuItem
        updateStatusItem()
    }

    private func updateStatusItem() {
        statusItem?.button?.image = AssetImage.menuBar(for: model.latestBattery)
        statusItem?.button?.title = model.menuBarBatteryText.map { " \($0)" } ?? ""
        statusItem?.button?.toolTip = "Charge Cat • \(model.menuBarStatusText)"
        batteryStatusMenuItem?.title = model.menuBarStatusText
        powerModeMenuItem?.title = "Power Mode • \(model.currentPowerMode.title)"
    }
}

private enum AssetImage {
    static func menuBar(for snapshot: BatterySnapshot?) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let mood = MenuBarCatMood.resolve(snapshot)
        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let head = NSBezierPath(roundedRect: NSRect(x: 3, y: 3, width: 12, height: 10), xRadius: 4, yRadius: 4)
        head.lineWidth = 1.6
        head.stroke()

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 5.2, y: 11.4))
        leftEar.line(to: NSPoint(x: 6.8, y: 15.4 + mood.earLift))
        leftEar.line(to: NSPoint(x: 8.1, y: 11.8))
        leftEar.close()
        leftEar.lineWidth = 1.4
        leftEar.stroke()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 9.9, y: 11.8))
        rightEar.line(to: NSPoint(x: 11.2, y: 15.4 + mood.earLift))
        rightEar.line(to: NSPoint(x: 12.8, y: 11.4))
        rightEar.close()
        rightEar.lineWidth = 1.4
        rightEar.stroke()

        drawEye(
            at: NSRect(x: 5.8, y: mood.eyeY, width: mood.eyeWidth, height: mood.eyeHeight),
            filled: mood.eyesFilled
        )
        drawEye(
            at: NSRect(x: 10.4, y: mood.eyeY, width: mood.eyeWidth, height: mood.eyeHeight),
            filled: mood.eyesFilled
        )

        if mood.cheekDots {
            NSBezierPath(ovalIn: NSRect(x: 4.8, y: 6.9, width: 0.9, height: 0.9)).fill()
            NSBezierPath(ovalIn: NSRect(x: 12.3, y: 6.9, width: 0.9, height: 0.9)).fill()
        }

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 8.4, y: mood.mouthY))
        mouth.curve(
            to: NSPoint(x: 9.6, y: mood.mouthY),
            controlPoint1: NSPoint(x: 8.8, y: mood.mouthY + mood.mouthCurve),
            controlPoint2: NSPoint(x: 9.2, y: mood.mouthY + mood.mouthCurve)
        )
        mouth.lineWidth = 1.1
        mouth.stroke()

        let whisker = NSBezierPath()
        whisker.move(to: NSPoint(x: 5.2, y: 7.8))
        whisker.line(to: NSPoint(x: 3.5, y: 7.2))
        whisker.move(to: NSPoint(x: 12.8, y: 7.8))
        whisker.line(to: NSPoint(x: 14.5, y: 7.2))
        whisker.lineWidth = 1
        whisker.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawEye(at rect: NSRect, filled: Bool) {
        let eye = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.height / 2)
        if filled {
            eye.fill()
        } else {
            eye.lineWidth = 1
            eye.stroke()
        }
    }

    private struct MenuBarCatMood {
        let earLift: CGFloat
        let eyeWidth: CGFloat
        let eyeHeight: CGFloat
        let eyeY: CGFloat
        let eyesFilled: Bool
        let mouthY: CGFloat
        let mouthCurve: CGFloat
        let cheekDots: Bool

        static func resolve(_ snapshot: BatterySnapshot?) -> Self {
            guard let snapshot else {
                return .regular
            }

            if snapshot.isCharging {
                return .charging
            }
            if snapshot.level <= 20 {
                return .low
            }
            if snapshot.level >= 80 {
                return .full
            }
            return .regular
        }

        static let low = MenuBarCatMood(
            earLift: -1.6,
            eyeWidth: 2.1,
            eyeHeight: 0.8,
            eyeY: 8.0,
            eyesFilled: true,
            mouthY: 6.2,
            mouthCurve: -0.5,
            cheekDots: false
        )

        static let regular = MenuBarCatMood(
            earLift: 0,
            eyeWidth: 1.4,
            eyeHeight: 1.4,
            eyeY: 8.0,
            eyesFilled: true,
            mouthY: 6.6,
            mouthCurve: 0.6,
            cheekDots: false
        )

        static let full = MenuBarCatMood(
            earLift: 0.8,
            eyeWidth: 1.6,
            eyeHeight: 1.6,
            eyeY: 8.2,
            eyesFilled: true,
            mouthY: 6.8,
            mouthCurve: 1.1,
            cheekDots: true
        )

        static let charging = MenuBarCatMood(
            earLift: 1.1,
            eyeWidth: 1.2,
            eyeHeight: 1.8,
            eyeY: 8.1,
            eyesFilled: true,
            mouthY: 6.9,
            mouthCurve: 1.3,
            cheekDots: true
        )
    }

    static var appIcon: NSImage? {
        ResourceBundle.current.image(forResource: NSImage.Name("AppIcon"))
    }
}
