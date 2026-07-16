import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var appLanguage: AppLanguage
    var preferredSide: ScreenSide
    var chargeStartAssetReference: OverlayAssetReference
    var fullChargeAssetReference: OverlayAssetReference
    var soundEnabled: Bool
    var autoMonitorEnabled: Bool
    var launchAtLoginEnabled: Bool

    var chargeTargetLevel: Int

    var previewBatteryLevel: Double
    var latestBattery: BatterySnapshot?
    var batteryMonitoringAvailable: Bool
    var currentPowerMode: PowerMode
    var lastEventDescription: String
    var launchAtLoginErrorMessage: String?
    var assetLibraryInfoMessage: String?
    var assetLibraryErrorMessage: String?
    var assetLibraryActivityText: String?
    var downloadableAssetCatalog: [OverlayAssetCatalogEntry]
    var installedOverlayAssets: [InstalledOverlayAsset]
    var downloadingAssetIDs: Set<String>
    var deletingAssetIDs: Set<String>
    let supportURL: URL
    let privacyPolicyURL: URL

    private var lastTriggerAt: Date?
    private var lastTriggerKind: OverlayEventKind?
    private weak var overlayPresenter: (any OverlayPresenting)?
    private let launchAtLogin: LaunchAtLogin
    private let assetLibrary: OverlayAssetLibrary
    private var downloadedOverlayAssetRecords: [DownloadedOverlayAssetRecord]
    private var powerModeRefreshTask: Task<Void, Never>?
    let soundPlayer: SoundPlayer
    var onMenuBarStateChanged: (@MainActor () -> Void)?

    init(
        launchAtLogin: LaunchAtLogin = LaunchAtLogin(),
        soundPlayer: SoundPlayer? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.soundPlayer = soundPlayer ?? SoundPlayer()

        let initialLanguage = UserSettings.appLanguage
        let configuration = BackendConfiguration.load()
        let assetLibrary = OverlayAssetLibrary(configuration: configuration)
        self.assetLibrary = assetLibrary
        supportURL = configuration.supportURL
        privacyPolicyURL = configuration.privacyPolicyURL
        let initialDownloadedAssets = assetLibrary.loadDownloadedAssets()
        downloadedOverlayAssetRecords = initialDownloadedAssets

        appLanguage = initialLanguage
        preferredSide = UserSettings.preferredSide
        let assignments = UserSettings.animationAssignments
        chargeStartAssetReference = assignments[.chargeStarted] ?? .bundled(.catDoor)
        fullChargeAssetReference = assignments[.fullyCharged] ?? .bundled(.fullBelly)
        soundEnabled = false
        autoMonitorEnabled = UserSettings.autoMonitorEnabled
        launchAtLoginEnabled = UserSettings.launchAtLoginEnabled
        chargeTargetLevel = UserSettings.chargeTargetLevel
        previewBatteryLevel = 38
        batteryMonitoringAvailable = true
        currentPowerMode = PowerModeReader.fallbackMode()
        lastEventDescription = AppCopy(language: initialLanguage).readyForNextChargingRitual
        launchAtLoginErrorMessage = nil
        assetLibraryInfoMessage = nil
        assetLibraryErrorMessage = nil
        assetLibraryActivityText = nil
        downloadableAssetCatalog = []
        installedOverlayAssets = assetLibrary.installedAssets(downloadedAssets: initialDownloadedAssets)
        downloadingAssetIDs = []
        deletingAssetIDs = []

        self.soundPlayer.isEnabled = false
        refreshLaunchAtLoginState()
        sanitizeAnimationAssignments()
    }

    /// 실제로 완충 트리거에 사용할 기준값.
    /// 완충 목표는 항상 사용자가 직접 지정한 값을 사용한다.
    var effectiveChargeTarget: Int {
        return chargeTargetLevel
    }

    var previewEventKind: OverlayEventKind {
        Int(previewBatteryLevel.rounded()) >= effectiveChargeTarget ? .fullyCharged : .chargeStarted
    }

    var previewAsset: InstalledOverlayAsset {
        resolvedAsset(for: previewEventKind)
    }

    var menuBarBatteryText: String? {
        latestBattery.map { "\($0.level)%" }
    }

    var menuBarStatusText: String {
        let copy = AppCopy(language: appLanguage)
        guard let latestBattery else {
            return copy.batteryUnavailable(powerMode: currentPowerMode)
        }
        return copy.menuBarStatus(
            level: latestBattery.level,
            powerText: copy.powerText(for: latestBattery),
            powerMode: currentPowerMode
        )
    }

    var copy: AppCopy {
        AppCopy(language: appLanguage)
    }

    var canCustomizeAnimations: Bool {
        true
    }

    var canManageDownloadableAssets: Bool {
        true
    }

    var hasAssetCatalog: Bool {
        assetLibrary.hasAssetCatalog
    }

    func bind(overlayPresenter: any OverlayPresenting) {
        self.overlayPresenter = overlayPresenter
    }

    func updateAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }
        let previousCopy = copy
        appLanguage = language
        UserSettings.appLanguage = language

        if lastEventDescription == previousCopy.readyForNextChargingRitual {
            lastEventDescription = copy.readyForNextChargingRitual
        } else if lastEventDescription == previousCopy.noBatteryDetectedPreviewStillWorks {
            lastEventDescription = copy.noBatteryDetectedPreviewStillWorks
        }

        onMenuBarStateChanged?()
    }

    func start() {
        Task {
            await refreshDownloadableAssets(showsProgress: false)
        }
        refreshPowerMode()
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

    func updateChargeTargetLevel(_ level: Int) {
        let clamped = ChargeTarget.clamp(level)
        chargeTargetLevel = clamped
        UserSettings.chargeTargetLevel = clamped
    }

    func assetReference(for event: OverlayEventKind) -> OverlayAssetReference {
        switch event {
        case .chargeStarted:
            return chargeStartAssetReference
        case .fullyCharged:
            return fullChargeAssetReference
        }
    }

    func resolvedAsset(for event: OverlayEventKind) -> InstalledOverlayAsset {
        let reference = assetReference(for: event)
        if let resolved = assetLibrary.resolve(reference: reference, downloadedAssets: downloadedOverlayAssetRecords) {
            return resolved
        }

        let fallback = assetLibrary.resolve(
            reference: event.defaultAssetReference,
            downloadedAssets: downloadedOverlayAssetRecords
        )
        if let fallback {
            return fallback
        }

        return assetLibrary.installedAssets(downloadedAssets: []).first!
    }

    func displayTitle(for asset: InstalledOverlayAsset) -> String {
        if let bundledAsset = asset.bundledAsset {
            return copy.title(for: bundledAsset)
        }
        return asset.customTitle ?? asset.reference.value
    }

    func assignedAssetTitle(for event: OverlayEventKind) -> String {
        displayTitle(for: resolvedAsset(for: event))
    }

    func updateAnimationAssignment(
        for event: OverlayEventKind,
        to reference: OverlayAssetReference
    ) {
        switch event {
        case .chargeStarted:
            chargeStartAssetReference = reference
        case .fullyCharged:
            fullChargeAssetReference = reference
        }

        persistAnimationAssignments()
    }

    func refreshDownloadableAssets(showsProgress: Bool) async {
        guard hasAssetCatalog else { return }

        if showsProgress {
            assetLibraryActivityText = copy.loadingAnimationCatalog
        }

        defer {
            if showsProgress {
                assetLibraryActivityText = nil
            }
        }

        do {
            downloadableAssetCatalog = try await assetLibrary.fetchCatalog()
            assetLibraryErrorMessage = nil
        } catch {
            if showsProgress {
                assetLibraryErrorMessage = localizedAssetMessage(for: error)
            }
        }
    }

    func downloadOverlayAsset(_ asset: OverlayAssetCatalogEntry) async {
        guard downloadingAssetIDs.contains(asset.id) == false else { return }

        downloadingAssetIDs.insert(asset.id)
        assetLibraryInfoMessage = nil
        assetLibraryErrorMessage = nil
        assetLibraryActivityText = copy.downloadingAnimation(name: asset.title)

        defer {
            downloadingAssetIDs.remove(asset.id)
            if downloadingAssetIDs.isEmpty {
                assetLibraryActivityText = nil
            }
        }

        do {
            downloadedOverlayAssetRecords = try await assetLibrary.download(
                asset,
                downloadedAssets: downloadedOverlayAssetRecords
            )
            installedOverlayAssets = assetLibrary.installedAssets(downloadedAssets: downloadedOverlayAssetRecords)
            sanitizeAnimationAssignments()
            assetLibraryInfoMessage = copy.downloadedAnimation(name: asset.title)
            assetLibraryErrorMessage = nil
        } catch {
            assetLibraryErrorMessage = localizedAssetMessage(for: error)
        }
    }

    func deleteOverlayAsset(_ asset: InstalledOverlayAsset) async {
        guard asset.isDownloaded else { return }
        guard deletingAssetIDs.contains(asset.id) == false else { return }

        deletingAssetIDs.insert(asset.id)
        assetLibraryInfoMessage = nil
        assetLibraryErrorMessage = nil
        assetLibraryActivityText = copy.removingAnimation(name: displayTitle(for: asset))

        defer {
            deletingAssetIDs.remove(asset.id)
            if deletingAssetIDs.isEmpty {
                assetLibraryActivityText = nil
            }
        }

        do {
            downloadedOverlayAssetRecords = try assetLibrary.deleteDownloadedAsset(
                id: asset.reference.value,
                downloadedAssets: downloadedOverlayAssetRecords
            )
            installedOverlayAssets = assetLibrary.installedAssets(downloadedAssets: downloadedOverlayAssetRecords)
            resetAssignmentsIfNeeded(removedReference: asset.reference)
            sanitizeAnimationAssignments()
            assetLibraryInfoMessage = copy.removedAnimation(name: displayTitle(for: asset))
            assetLibraryErrorMessage = nil
        } catch {
            assetLibraryErrorMessage = localizedAssetMessage(for: error)
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
            lastEventDescription = copy.launchAtLoginCouldNotBeChanged
        }
    }

    func updateBattery(_ snapshot: BatterySnapshot?) {
        latestBattery = snapshot
        batteryMonitoringAvailable = snapshot != nil
        onMenuBarStateChanged?()
        schedulePowerModeRefresh(isPluggedIn: snapshot?.isPluggedIn)

        guard snapshot == nil else {
            if lastEventDescription == copy.noBatteryDetectedPreviewStillWorks {
                lastEventDescription = copy.readyForNextChargingRitual
            }
            return
        }

        if lastEventDescription == copy.readyForNextChargingRitual || lastEventDescription == copy.noBatteryDetectedPreviewStillWorks {
            lastEventDescription = copy.noBatteryDetectedPreviewStillWorks
        }
    }

    func refreshPowerMode() {
        schedulePowerModeRefresh(isPluggedIn: latestBattery?.isPluggedIn)
    }

    func trigger(_ kind: OverlayEventKind, level: Int? = nil, source: String = "preview") {
        let resolvedLevel = min(max(level ?? Int(previewBatteryLevel.rounded()), 1), 100)

        guard shouldThrottle(kind: kind, source: source) == false else {
            lastEventDescription = copy.duplicateTriggerMessage(for: kind)
            return
        }

        lastTriggerAt = Date()
        lastTriggerKind = kind
        let asset = resolvedAsset(for: kind)

        let payload = OverlayPayload(
            id: UUID(),
            kind: kind,
            batteryLevel: resolvedLevel,
            side: preferredSide,
            asset: asset,
            animationType: AnimationPicker.selectAnimation(for: kind)
        )

        lastEventDescription = copy.triggerMessage(
            kind: kind,
            source: source,
            level: resolvedLevel,
            side: preferredSide,
            assetTitle: displayTitle(for: asset)
        )
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

    private func schedulePowerModeRefresh(isPluggedIn: Bool?) {
        powerModeRefreshTask?.cancel()
        powerModeRefreshTask = Task { [weak self] in
            let powerMode = await PowerModeReader.readCurrentModeAsync(isPluggedIn: isPluggedIn)
            guard Task.isCancelled == false, let self else { return }
            self.currentPowerMode = powerMode
            self.onMenuBarStateChanged?()
        }
    }

    private func persistAnimationAssignments() {
        UserSettings.animationAssignments = [
            .chargeStarted: chargeStartAssetReference,
            .fullyCharged: fullChargeAssetReference
        ]
    }

    private func sanitizeAnimationAssignments() {
        let installedReferenceIDs = Set(installedOverlayAssets.map(\.reference.id))
        var didChange = false

        if installedReferenceIDs.contains(chargeStartAssetReference.id) == false,
           chargeStartAssetReference != .bundled(.catDoor) {
            chargeStartAssetReference = .bundled(.catDoor)
            didChange = true
        }

        if installedReferenceIDs.contains(fullChargeAssetReference.id) == false,
           fullChargeAssetReference != .bundled(.fullBelly) {
            fullChargeAssetReference = .bundled(.fullBelly)
            didChange = true
        }

        if didChange {
            persistAnimationAssignments()
        }
    }

    private func resetAssignmentsIfNeeded(removedReference: OverlayAssetReference) {
        var didChange = false

        if chargeStartAssetReference == removedReference {
            chargeStartAssetReference = .bundled(.catDoor)
            didChange = true
        }

        if fullChargeAssetReference == removedReference {
            fullChargeAssetReference = .bundled(.fullBelly)
            didChange = true
        }

        if didChange {
            persistAnimationAssignments()
        }
    }

    private func localizedAssetMessage(for error: Error) -> String {
        if let error = error as? OverlayAssetLibraryError {
            switch error {
            case .notConfigured:
                return copy.downloadableAssetsNotConfigured
            case .catalogUnavailable, .invalidCatalog:
                return copy.couldNotLoadAnimationCatalog
            case .downloadFailed:
                return copy.couldNotDownloadAnimation
            case .localFileMissing:
                return copy.downloadedAnimationMissing
            }
        }
        return error.localizedDescription
    }
}
