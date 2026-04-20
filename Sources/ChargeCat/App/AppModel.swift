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
    var licenseKeyDraft: String
    var customerEmailDraft: String
    var maskedLicenseKey: String?
    var licenseInfoMessage: String?
    var licenseErrorMessage: String?
    var licenseActivityText: String?
    var assetLibraryInfoMessage: String?
    var assetLibraryErrorMessage: String?
    var assetLibraryActivityText: String?
    var downloadableAssetCatalog: [OverlayAssetCatalogEntry]
    var installedOverlayAssets: [InstalledOverlayAsset]
    var downloadingAssetIDs: Set<String>
    var deletingAssetIDs: Set<String>
    let entitlementStore: EntitlementStore

    private var lastTriggerAt: Date?
    private var lastTriggerKind: OverlayEventKind?
    private weak var overlayPresenter: (any OverlayPresenting)?
    private let launchAtLogin: LaunchAtLogin
    private let licensingService: LemonLicenseService
    private let checkoutService: ProCheckoutService
    private let assetLibrary: OverlayAssetLibrary
    private var downloadedOverlayAssetRecords: [DownloadedOverlayAssetRecord]
    private var licenseRevision = 0
    private var checkoutPollingTask: Task<Void, Never>?
    let soundPlayer: SoundPlayer
    var onMenuBarStateChanged: (@MainActor () -> Void)?

    init(
        launchAtLogin: LaunchAtLogin = LaunchAtLogin(),
        soundPlayer: SoundPlayer? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.soundPlayer = soundPlayer ?? SoundPlayer()

        let licensePreferences = LicensePreferencesStore()
        let loadedLicenseState = licensePreferences.load()
        let entitlementStore = EntitlementStore(initialState: loadedLicenseState, preferences: licensePreferences)
        let initialLanguage = UserSettings.appLanguage
        self.entitlementStore = entitlementStore
        appLanguage = initialLanguage
        let licensingService = LemonLicenseService(
            currentState: { entitlementStore.state },
            currentLanguage: { UserSettings.appLanguage }
        )
        self.licensingService = licensingService
        checkoutService = ProCheckoutService(configuration: licensingService.configuration)
        let assetLibrary = OverlayAssetLibrary(configuration: licensingService.configuration)
        self.assetLibrary = assetLibrary
        let initialDownloadedAssets = assetLibrary.loadDownloadedAssets()
        downloadedOverlayAssetRecords = initialDownloadedAssets

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
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: nil)
        lastEventDescription = AppCopy(language: initialLanguage).readyForNextChargingRitual
        licenseKeyDraft = ""
        customerEmailDraft = loadedLicenseState.customerEmail ?? ""
        maskedLicenseKey = licensingService.snapshot(allowsAuthenticationUI: false).maskedLicenseKey
        licenseInfoMessage = nil
        licenseErrorMessage = nil
        licenseActivityText = nil
        assetLibraryInfoMessage = nil
        assetLibraryErrorMessage = nil
        assetLibraryActivityText = nil
        downloadableAssetCatalog = []
        installedOverlayAssets = assetLibrary.installedAssets(downloadedAssets: initialDownloadedAssets)
        downloadingAssetIDs = []
        deletingAssetIDs = []

        self.soundPlayer.isEnabled = false
        refreshLaunchAtLoginState()
        self.entitlementStore.apply(licensingService.sanitizeInitialState(loadedLicenseState))
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

    var licenseState: LicenseState {
        entitlementStore.state
    }

    var licenseConfiguration: LicensingConfiguration {
        licensingService.configuration
    }

    var canStartProCheckout: Bool {
        licenseConfiguration.hasCheckoutEntryPoint
    }

    var canCustomizeAnimations: Bool {
        entitlementStore.isEnabled(.animationCustomization)
    }

    var canManageDownloadableAssets: Bool {
        entitlementStore.isEnabled(.downloadableAssets)
    }

    var hasAssetCatalog: Bool {
        licenseConfiguration.assetCatalogURL != nil
    }

    var hasStoredLicense: Bool {
        licenseState.status != .free || licenseState.lastKnownTier == .pro || maskedLicenseKey != nil
    }

    var isLicenseBusy: Bool {
        licenseActivityText != nil
    }

    var licenseWarningText: String {
        copy.title(for: licenseState.warningState)
    }

    var licenseSummaryText: String {
        switch licenseState.status {
        case .free:
            return copy.coreFeaturesStayFree
        case .proVerified:
            return copy.fullyVerified(productName: licenseConfiguration.productName)
        case .proCached:
            return copy.cachedProSummary
        case .revoked:
            return copy.revokedProSummary
        case .invalid:
            return copy.invalidProSummary
        }
    }

    var licenseLastValidatedText: String {
        formatted(date: licenseState.lastValidatedAt)
    }

    var licenseLastAttemptText: String {
        formatted(date: licenseState.lastValidationAttemptAt)
    }

    var licenseNextRetryText: String {
        formatted(date: licenseState.nextRetryAt)
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
            await refreshLicense(force: false, reason: "launch", showsProgress: false)
            await refreshDownloadableAssets(showsProgress: false)
        }
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
        let storedReference: OverlayAssetReference = switch event {
        case .chargeStarted:
            chargeStartAssetReference
        case .fullyCharged:
            fullChargeAssetReference
        }

        if canCustomizeAnimations {
            return storedReference
        }
        return event.defaultAssetReference
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
        guard canCustomizeAnimations else { return }

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
        guard canManageDownloadableAssets else { return }
        guard downloadingAssetIDs.contains(asset.id) == false else { return }
        guard let authorization = licensingService.assetDownloadAuthorization(allowsAuthenticationUI: true) else {
            assetLibraryErrorMessage = copy.noSavedProLicense
            return
        }

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
                authorization: authorization,
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
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: snapshot?.isPluggedIn)
        onMenuBarStateChanged?()

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
        currentPowerMode = PowerModeReader.readCurrentMode(isPluggedIn: latestBattery?.isPluggedIn)
        onMenuBarStateChanged?()
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

    func startUpgradeToPro() async {
        guard isLicenseBusy == false else { return }

        licenseRevision += 1
        let currentRevision = licenseRevision
        checkoutPollingTask?.cancel()
        licenseInfoMessage = nil
        licenseErrorMessage = nil

        guard licenseConfiguration.hasCheckoutEntryPoint else {
            licenseErrorMessage = copy.checkoutBackendUnavailable
            return
        }

        guard licenseConfiguration.checkoutSessionsURL != nil else {
            licensingService.open(licenseConfiguration.checkoutURL)
            licenseInfoMessage = copy.checkoutOpenedInBrowser
            return
        }
        licenseActivityText = copy.preparingSecureCheckout

        do {
            let installationID = licensingService.installationID()
            let checkoutSession = try await checkoutService.createCheckoutSession(
                installationId: installationID,
                customerEmail: customerEmailDraft,
                appVersion: appVersionString
            )
            guard licenseRevision == currentRevision else { return }

            licensingService.open(checkoutSession.checkoutURL)
            licenseInfoMessage = copy.checkoutOpenedInBrowser
            licenseErrorMessage = nil
            licenseActivityText = copy.waitingForCheckoutCompletion
            beginCheckoutPolling(
                sessionID: checkoutSession.sessionID,
                installationID: installationID,
                currentRevision: currentRevision,
                immediate: false
            )
        } catch let error as ProCheckoutError {
            guard licenseRevision == currentRevision else { return }
            licenseActivityText = nil
            licenseErrorMessage = localizedMessage(for: error)
        } catch {
            guard licenseRevision == currentRevision else { return }
            licenseActivityText = nil
            licenseErrorMessage = error.localizedDescription
        }
    }

    func handleExternalURL(_ url: URL) {
        guard url.scheme?.lowercased() == LicensingConfiguration.appURLScheme else { return }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        guard host == "checkout-complete" || path == "/checkout-complete" else { return }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sessionID = components.queryItems?.first(where: { $0.name == "session_id" })?.value,
              sessionID.isEmpty == false else {
            return
        }

        licenseRevision += 1
        let currentRevision = licenseRevision
        licenseInfoMessage = copy.checkoutOpenedInBrowser
        licenseErrorMessage = nil
        licenseActivityText = copy.waitingForCheckoutCompletion
        beginCheckoutPolling(
            sessionID: sessionID,
            installationID: licensingService.installationID(),
            currentRevision: currentRevision,
            immediate: true
        )
    }

    func openMyOrders() {
        licensingService.open(licenseConfiguration.myOrdersURL)
    }

    func openSupport() {
        licensingService.open(licenseConfiguration.supportURL)
    }

    func activateLicense() async {
        guard isLicenseBusy == false else { return }

        licenseRevision += 1
        let currentRevision = licenseRevision
        checkoutPollingTask?.cancel()
        licenseInfoMessage = nil
        licenseErrorMessage = nil
        licenseActivityText = copy.activatingOnThisMac

        defer {
            if licenseRevision == currentRevision {
                licenseActivityText = nil
            }
        }

        do {
            let state = try await licensingService.activate(
                licenseKey: licenseKeyDraft,
                customerEmail: customerEmailDraft
            )
            guard licenseRevision == currentRevision else { return }

            entitlementStore.apply(state)
            maskedLicenseKey = maskLicenseKey(licenseKeyDraft)
            licenseKeyDraft = ""
            customerEmailDraft = state.customerEmail ?? customerEmailDraft
            licenseInfoMessage = copy.fullyVerified(productName: licenseConfiguration.productName)
            licenseErrorMessage = nil
        } catch let error as LicensingError {
            guard licenseRevision == currentRevision else { return }
            if entitlementStore.state.hasProAccess == false, let suggestedState = error.suggestedState {
                entitlementStore.apply(suggestedState)
            }
            licenseErrorMessage = localizedMessage(for: error)
        } catch {
            guard licenseRevision == currentRevision else { return }
            licenseErrorMessage = error.localizedDescription
        }
    }

    func refreshLicense(
        force: Bool,
        reason: String,
        showsProgress: Bool
    ) async {
        let currentRevision = licenseRevision

        if force == false,
           let lastValidatedAt = entitlementStore.state.lastValidatedAt,
           Date().timeIntervalSince(lastValidatedAt) < LicensingConfiguration.defaultValidationInterval {
            entitlementStore.apply(entitlementStore.state.refreshedWarning())
            return
        }

        if showsProgress, licenseActivityText == nil {
            licenseActivityText = copy.refreshingProStatus
        }

        let state = await licensingService.validateCachedLicense(
            force: force,
            allowsAuthenticationUI: showsProgress
        )
        guard licenseRevision == currentRevision else { return }

        entitlementStore.apply(state)
        if showsProgress {
            maskedLicenseKey = licensingService.snapshot(allowsAuthenticationUI: true).maskedLicenseKey ?? maskedLicenseKey
        }
        if let customerEmail = state.customerEmail, customerEmail.isEmpty == false {
            customerEmailDraft = customerEmail
        }

        if showsProgress {
            licenseInfoMessage = state.status == .proVerified ? copy.proUpToDate : nil
        }

        if let lastErrorMessage = state.lastErrorMessage, state.status == .proCached {
            licenseErrorMessage = lastErrorMessage
        } else {
            licenseErrorMessage = nil
        }

        if showsProgress {
            licenseActivityText = nil
        }

        if reason == "launch", state.status == .proVerified {
            licenseInfoMessage = nil
        }
    }

    func deactivateCurrentMac() async {
        guard isLicenseBusy == false else { return }

        licenseRevision += 1
        let currentRevision = licenseRevision
        checkoutPollingTask?.cancel()
        licenseInfoMessage = nil
        licenseErrorMessage = nil
        licenseActivityText = copy.removingThisMacFromLemon

        defer {
            if licenseRevision == currentRevision {
                licenseActivityText = nil
            }
        }

        do {
            let state = try await licensingService.deactivateCurrentMac()
            guard licenseRevision == currentRevision else { return }

            entitlementStore.apply(state)
            maskedLicenseKey = nil
            licenseKeyDraft = ""
            customerEmailDraft = ""
            licenseInfoMessage = copy.removedThisMacFromPro
        } catch let error as LicensingError {
            guard licenseRevision == currentRevision else { return }
            licenseErrorMessage = localizedMessage(for: error)
        } catch {
            guard licenseRevision == currentRevision else { return }
            licenseErrorMessage = error.localizedDescription
        }
    }

    private func beginCheckoutPolling(
        sessionID: String,
        installationID: String,
        currentRevision: Int,
        immediate: Bool
    ) {
        checkoutPollingTask?.cancel()
        checkoutPollingTask = Task { [weak self] in
            await self?.pollCheckoutSession(
                sessionID: sessionID,
                installationID: installationID,
                currentRevision: currentRevision,
                immediate: immediate
            )
        }
    }

    private func pollCheckoutSession(
        sessionID: String,
        installationID: String,
        currentRevision: Int,
        immediate: Bool
    ) async {
        let startedAt = Date()
        var shouldDelay = immediate == false
        var lastTransientError: String?

        while Task.isCancelled == false,
              Date().timeIntervalSince(startedAt) < 15 * 60 {
            if shouldDelay {
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
            } else {
                shouldDelay = true
            }

            guard licenseRevision == currentRevision else { return }

            do {
                let session = try await checkoutService.fetchCheckoutSession(
                    id: sessionID,
                    installationId: installationID
                )
                guard licenseRevision == currentRevision else { return }

                switch session.status {
                case .pending:
                    licenseActivityText = copy.waitingForCheckoutCompletion

                case .ready:
                    if hasStoredLicense || entitlementStore.state.hasProAccess {
                        _ = try? await checkoutService.claimCheckoutSession(
                            id: sessionID,
                            installationId: installationID
                        )
                        guard licenseRevision == currentRevision else { return }
                        licenseActivityText = nil
                        licenseInfoMessage = copy.alreadyUnlockedOnThisMac
                        licenseErrorMessage = nil
                        return
                    }

                    guard let licenseKey = session.licenseKey else {
                        licenseActivityText = nil
                        licenseErrorMessage = ProCheckoutError.invalidResponse.localizedDescription
                        return
                    }

                    licenseActivityText = copy.finishingCheckoutActivation

                    do {
                        let state = try await licensingService.activate(
                            licenseKey: licenseKey,
                            customerEmail: session.customerEmail ?? customerEmailDraft
                        )
                        _ = try? await checkoutService.claimCheckoutSession(
                            id: sessionID,
                            installationId: installationID
                        )
                        guard licenseRevision == currentRevision else { return }

                        entitlementStore.apply(state)
                        maskedLicenseKey = maskLicenseKey(licenseKey)
                        licenseKeyDraft = ""
                        customerEmailDraft = state.customerEmail ?? customerEmailDraft
                        licenseInfoMessage = copy.proActivatedFromCheckout(productName: licenseConfiguration.productName)
                        licenseErrorMessage = nil
                        licenseActivityText = nil
                        return
                    } catch let error as LicensingError {
                        guard licenseRevision == currentRevision else { return }
                        licenseActivityText = nil
                        licenseKeyDraft = licenseKey
                        customerEmailDraft = session.customerEmail ?? customerEmailDraft
                        licenseErrorMessage = localizedMessage(for: error)
                        return
                    } catch {
                        guard licenseRevision == currentRevision else { return }
                        licenseActivityText = nil
                        licenseKeyDraft = licenseKey
                        customerEmailDraft = session.customerEmail ?? customerEmailDraft
                        licenseErrorMessage = error.localizedDescription
                        return
                    }

                case .claimed:
                    licenseActivityText = nil
                    licenseInfoMessage = entitlementStore.state.hasProAccess ? copy.alreadyUnlockedOnThisMac : licenseInfoMessage
                    licenseErrorMessage = nil
                    return

                case .expired:
                    licenseActivityText = nil
                    licenseErrorMessage = copy.checkoutSessionExpired
                    return

                case .failed:
                    licenseActivityText = nil
                    licenseErrorMessage = session.lastError ?? copy.checkoutBackendUnavailable
                    return
                }
            } catch let error as ProCheckoutError {
                lastTransientError = localizedMessage(for: error)
            } catch {
                lastTransientError = error.localizedDescription
            }
        }

        guard licenseRevision == currentRevision else { return }
        licenseActivityText = nil
        if let lastTransientError {
            licenseErrorMessage = lastTransientError
        } else {
            licenseInfoMessage = copy.checkoutStillWaiting
        }
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

    private func formatted(date: Date?) -> String {
        guard let date else { return copy.notYet }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: appLanguage.localeIdentifier)
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func localizedMessage(for error: LicensingError) -> String {
        switch error {
        case .notConfigured:
            return copy.proCheckoutNotConfigured
        case .missingStoredLicense:
            return copy.noSavedProLicense
        case let .invalid(message, _),
             let .revoked(message, _),
             let .transient(message):
            return message
        }
    }

    private func localizedMessage(for error: ProCheckoutError) -> String {
        switch error {
        case .notConfigured:
            return copy.checkoutBackendUnavailable
        case .invalidResponse:
            return copy.checkoutBackendUnavailable
        case let .server(message):
            return message
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

    private func maskLicenseKey(_ licenseKey: String) -> String? {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return nil }
        return "\(trimmed.prefix(4))••••\(trimmed.suffix(4))"
    }

    private var appVersionString: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           value.isEmpty == false {
            return value
        }
        return "dev"
    }
}
