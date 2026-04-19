import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var preferredSide: ScreenSide
    var selectedAnimationAsset: OverlayAnimationAsset
    var soundEnabled: Bool
    var autoMonitorEnabled: Bool
    var launchAtLoginEnabled: Bool

    var chargeTargetFollowsSystem: Bool
    var chargeTargetLevel: Int
    var systemChargeLimit: Int?

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
        selectedAnimationAsset = UserSettings.selectedAnimationAsset
        soundEnabled = false
        autoMonitorEnabled = UserSettings.autoMonitorEnabled
        launchAtLoginEnabled = UserSettings.launchAtLoginEnabled
        chargeTargetFollowsSystem = UserSettings.chargeTargetFollowsSystem
        chargeTargetLevel = UserSettings.chargeTargetLevel
        systemChargeLimit = ChargeLimitReader.readSystemChargeLimit()
        previewBatteryLevel = 38
        batteryMonitoringAvailable = true
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: nil)
        lastEventDescription = "Ready for the next charging ritual."

        self.soundPlayer.isEnabled = false
        refreshLaunchAtLoginState()
        syncChargeTargetWithSystemIfNeeded()
    }

    /// 실제로 완충 트리거에 사용할 기준값.
    /// 시스템 연동 모드에서는 읽어온 값(없으면 100)을 사용하고, 수동 모드에서는 사용자 지정값을 사용한다.
    var effectiveChargeTarget: Int {
        if chargeTargetFollowsSystem {
            return systemChargeLimit ?? 100
        }
        return chargeTargetLevel
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

    func updateSelectedAnimationAsset(_ asset: OverlayAnimationAsset) {
        selectedAnimationAsset = asset
        UserSettings.selectedAnimationAsset = asset
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

    func updateChargeTargetFollowsSystem(_ followsSystem: Bool) {
        chargeTargetFollowsSystem = followsSystem
        UserSettings.chargeTargetFollowsSystem = followsSystem
        syncChargeTargetWithSystemIfNeeded()
    }

    func updateChargeTargetLevel(_ level: Int) {
        let clamped = ChargeTarget.clamp(level)
        chargeTargetLevel = clamped
        UserSettings.chargeTargetLevel = clamped
    }

    func refreshSystemChargeLimit() {
        let latest = ChargeLimitReader.readSystemChargeLimit()
        // 값이 바뀐 경우에만 반영 — Observable이 매 폴링마다 notify해서
        // GIFAnimationView가 리셋되는 것을 방지한다.
        if latest != systemChargeLimit {
            systemChargeLimit = latest
        }
        syncChargeTargetWithSystemIfNeeded()
    }

    private func syncChargeTargetWithSystemIfNeeded() {
        guard chargeTargetFollowsSystem, let systemChargeLimit else { return }
        let clamped = ChargeTarget.clamp(systemChargeLimit)
        if chargeTargetLevel != clamped {
            chargeTargetLevel = clamped
            UserSettings.chargeTargetLevel = clamped
        }
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
            asset: selectedAnimationAsset,
            animationType: AnimationPicker.selectAnimation(for: kind)
        )

        lastEventDescription = "\(kind.title) from \(source) at \(resolvedLevel)% on the \(preferredSide.title.lowercased()) side with \(selectedAnimationAsset.title)."
        overlayPresenter?.present(payload: payload)
    }

    func completeOnboarding(launchAtLoginEnabled desiredLaunchAtLogin: Bool) {
        if desiredLaunchAtLogin != launchAtLoginEnabled {
            updateLaunchAtLogin(desiredLaunchAtLogin)
        }
    }

    func resetTriggerHistory() {
        lastTriggerAt = nil
        lastTriggerKind = nil
    }

    private func shouldThrottle(kind: OverlayEventKind, source: String) -> Bool {
        guard source == "system",
              let lastTriggerAt,
              let lastTriggerKind
        else {
            return false
        }

        return lastTriggerKind == kind && Date().timeIntervalSince(lastTriggerAt) < 2
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = launchAtLogin.isEnabled || UserSettings.launchAtLoginEnabled
    }
}
