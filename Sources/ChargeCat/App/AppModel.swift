import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var preferredSide: ScreenSide
    var soundEnabled: Bool
    var autoMonitorEnabled: Bool
    var launchAtLoginEnabled: Bool

    var previewBatteryLevel: Double
    var latestBattery: BatterySnapshot?
    var batteryMonitoringAvailable: Bool
    var currentPowerMode: PowerMode
    var lastEventDescription: String
    var launchAtLoginErrorMessage: String?

    private var lastTriggerAt: Date?
    private var lastTriggerKind: OverlayEventKind?
    private weak var overlayPresenter: (any OverlayPresenting)?
    private let launchAtLogin: LaunchAtLogin
    let soundPlayer: SoundPlayer
    var onMenuBarStateChanged: (@MainActor () -> Void)?

    init(
        launchAtLogin: LaunchAtLogin = LaunchAtLogin(),
        soundPlayer: SoundPlayer? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.soundPlayer = soundPlayer ?? SoundPlayer()
        preferredSide = UserSettings.preferredSide
        soundEnabled = false
        autoMonitorEnabled = UserSettings.autoMonitorEnabled
        launchAtLoginEnabled = UserSettings.launchAtLoginEnabled
        previewBatteryLevel = 38
        batteryMonitoringAvailable = true
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: nil)
        lastEventDescription = "Ready for the next charging ritual."

        self.soundPlayer.isEnabled = false
        refreshLaunchAtLoginState()
    }

    var menuBarBatteryText: String? {
        latestBattery.map { "\($0.level)%" }
    }

    var menuBarStatusText: String {
        guard let latestBattery else {
            return "Battery unavailable • \(currentPowerMode.title)"
        }
        return "Battery \(latestBattery.level)% • \(latestBattery.powerText) • \(currentPowerMode.title)"
    }

    func bind(overlayPresenter: any OverlayPresenting) {
        self.overlayPresenter = overlayPresenter
    }

    func updatePreferredSide(_ side: ScreenSide) {
        preferredSide = side
        UserSettings.preferredSide = side
    }

    func updateSoundEnabled(_ isEnabled: Bool) {
        soundEnabled = isEnabled
        UserSettings.soundEnabled = isEnabled
        soundPlayer.isEnabled = isEnabled
    }

    func updateAutoMonitorEnabled(_ isEnabled: Bool) {
        autoMonitorEnabled = isEnabled
        UserSettings.autoMonitorEnabled = isEnabled
    }

    func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try launchAtLogin.setEnabled(isEnabled)
            launchAtLoginEnabled = isEnabled
            UserSettings.launchAtLoginEnabled = isEnabled
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginEnabled = launchAtLogin.isEnabled
            launchAtLoginErrorMessage = error.localizedDescription
            lastEventDescription = "Launch at Login couldn't be changed in this build."
        }
    }

    func updateBattery(_ snapshot: BatterySnapshot?) {
        latestBattery = snapshot
        batteryMonitoringAvailable = snapshot != nil
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: snapshot?.isPluggedIn)
        onMenuBarStateChanged?()

        guard snapshot == nil else {
            if lastEventDescription.hasPrefix("No battery") {
                lastEventDescription = "Ready for the next charging ritual."
            }
            return
        }

        if lastEventDescription == "Ready for the next charging ritual." || lastEventDescription.hasPrefix("No battery") {
            lastEventDescription = "No battery detected. Preview buttons still work on this Mac."
        }
    }

    func refreshPowerMode() {
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: latestBattery?.isPluggedIn)
        onMenuBarStateChanged?()
    }

    func trigger(_ kind: OverlayEventKind, level: Int? = nil, source: String = "preview") {
        let resolvedLevel = min(max(level ?? Int(previewBatteryLevel.rounded()), 1), 100)

        guard shouldThrottle(kind: kind, source: source) == false else {
            lastEventDescription = "\(kind.title) ignored to avoid a duplicate trigger."
            return
        }

        lastTriggerAt = Date()
        lastTriggerKind = kind

        let payload = OverlayPayload(
            id: UUID(),
            kind: kind,
            batteryLevel: resolvedLevel,
            side: preferredSide,
            animationType: AnimationPicker.selectAnimation(for: kind)
        )

        lastEventDescription = "\(kind.title) from \(source) at \(resolvedLevel)% on the \(preferredSide.title.lowercased()) side."
        overlayPresenter?.present(payload: payload)
    }

    func completeOnboarding(launchAtLoginEnabled desiredLaunchAtLogin: Bool) {
        if desiredLaunchAtLogin != launchAtLoginEnabled {
            updateLaunchAtLogin(desiredLaunchAtLogin)
        }
    }

    private func shouldThrottle(kind: OverlayEventKind, source: String) -> Bool {
        guard source == "system",
              let lastTriggerAt,
              let lastTriggerKind
        else {
            return false
        }

        return lastTriggerKind == kind && Date().timeIntervalSince(lastTriggerAt) < 10
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = launchAtLogin.isEnabled || UserSettings.launchAtLoginEnabled
    }
}
