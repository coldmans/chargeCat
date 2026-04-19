import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .korean:
            return "KOR"
        case .english:
            return "ENG"
        }
    }

    var localeIdentifier: String {
        rawValue
    }
}

struct AppCopy {
    let language: AppLanguage

    private var isKorean: Bool {
        language == .korean
    }

    var appName: String { "Charge Cat" }
    var versionBadge: String { "v1.0" }

    var panelHeadline: String {
        isKorean ? "맥이 충전을 시작하는 순간의 작은 의식." : "A tiny ritual for the moment your Mac starts charging."
    }

    var panelSubheadline: String {
        isKorean
            ? "코너를 고르고, 분위기를 맞추고, 다음 실제 충전 전에 고양이를 미리 확인해보세요."
            : "Pick a corner, tune the mood, and preview the cat before the next real power event."
    }

    var settings: String { isKorean ? "설정" : "Settings" }
    var animation: String { isKorean ? "애니메이션" : "Animation" }
    var screenCorner: String { isKorean ? "화면 코너" : "Screen Corner" }
    var testCharge: String { isKorean ? "충전 테스트" : "Test Charge" }
    var testFull: String { isKorean ? "완충 테스트" : "Test Full" }
    var autoReactToRealCharging: String { isKorean ? "실제 충전에 자동 반응" : "Auto-react to real charging" }
    var launchAtLogin: String { isKorean ? "로그인 시 자동 실행" : "Launch at Login" }
    var fullChargeTarget: String { isKorean ? "완충 목표" : "Full Charge Target" }
    var cornerPreview: String { isKorean ? "코너 미리보기" : "Corner Preview" }
    var liveStatus: String { isKorean ? "실시간 상태" : "Live Status" }
    var noBatteryDataDetectedYet: String { isKorean ? "아직 배터리 데이터를 찾지 못했어요." : "No battery data detected yet." }

    var onboardingTitle: String { isKorean ? "Charge Cat 준비 완료." : "Charge Cat is ready." }
    var onboardingSubtitle: String { isKorean ? "맥에 전원을 연결하면 작은 고양이가 나와 인사해요." : "Plug in your Mac and a tiny cat will step out to say hello." }
    var getStarted: String { isKorean ? "시작하기" : "Get Started" }

    var proSectionTitle: String { "Charge Cat Pro" }
    var proPrimaryCTA: String { isKorean ? "Pro 구매하기" : "Buy Pro" }
    var proHeroTitle: String {
        isKorean ? "앱에서 결제하면 Pro가 자동으로 열려요." : "Buy from the app and Charge Cat unlocks Pro automatically."
    }
    var proHeroSubtitle: String {
        isKorean
            ? "브라우저에서 안전하게 결제를 마치면 Charge Cat이 이 Mac에서 자동으로 활성화를 이어갑니다. 중간에 끊기면 아래 수동 활성화로 바로 이어갈 수 있어요."
            : "Charge Cat opens a secure browser checkout, then automatically finishes activation on this Mac after payment. If anything interrupts the flow, you can still use manual activation below."
    }
    var alreadyPurchased: String { isKorean ? "이미 구매했어요" : "Already purchased?" }
    var activatePurchasedPro: String { isKorean ? "구매한 라이선스 활성화" : "Activate a purchased license" }
    var activatePurchasedProSubtitle: String {
        isKorean
            ? "자동 활성화가 끊겼거나 웹에서 구매했다면, 주문 메일이나 My Orders의 라이선스 키로 바로 이어갈 수 있어요."
            : "If automatic activation is interrupted or you purchased on the web, paste the key from your receipt email or My Orders here."
    }
    var proNotConfigured: String {
        isKorean
            ? "이 빌드에는 Pro 결제가 아직 연결되지 않았어요. 출시 전 licensing-config.json 리소스를 채워주세요."
            : "Pro checkout is not configured in this build yet. Fill the licensing-config.json resource before shipping."
    }
    var licenseKeyPlaceholder: String { isKorean ? "라이선스 키" : "License key" }
    var receiptEmailOptional: String { isKorean ? "구매 이메일 (선택)" : "Receipt email (optional)" }
    var upgradeToPro: String { isKorean ? "Pro 업그레이드" : "Upgrade to Pro" }
    var activateLicense: String { isKorean ? "라이선스 활성화" : "Activate License" }
    var refreshLicense: String { isKorean ? "라이선스 새로고침" : "Refresh License" }
    var deactivateThisMac: String { isKorean ? "이 Mac 비활성화" : "Deactivate This Mac" }
    var myOrders: String { isKorean ? "주문 내역" : "My Orders" }
    var support: String { isKorean ? "지원" : "Support" }
    var status: String { isKorean ? "상태" : "Status" }
    var savedKey: String { isKorean ? "저장된 키" : "Saved key" }
    var receiptEmail: String { isKorean ? "구매 이메일" : "Receipt email" }
    var lastVerified: String { isKorean ? "마지막 검증" : "Last verified" }
    var lastAttempt: String { isKorean ? "마지막 시도" : "Last attempt" }
    var nextRetry: String { isKorean ? "다음 재시도" : "Next retry" }
    var noneOnThisMac: String { isKorean ? "이 Mac에는 없음" : "None on this Mac" }
    var notSaved: String { isKorean ? "저장 안 함" : "Not saved" }
    var proFooter: String {
        isKorean
            ? "기본 기능은 계속 무료예요. Pro는 프리미엄 기능과 앞으로의 추가 팩을 위한 자리예요."
            : "Free features stay free. Pro is ready for premium add-ons and future packs."
    }

    var readyForNextChargingRitual: String {
        isKorean ? "다음 충전 의식을 기다리는 중이에요." : "Ready for the next charging ritual."
    }

    var launchAtLoginCouldNotBeChanged: String {
        isKorean
            ? "이 빌드에서는 로그인 시 자동 실행을 바꾸지 못했어요."
            : "Launch at Login couldn't be changed in this build."
    }

    var noBatteryDetectedPreviewStillWorks: String {
        isKorean
            ? "이 Mac에서는 배터리를 찾지 못했어요. 미리보기 버튼은 계속 쓸 수 있어요."
            : "No battery detected. Preview buttons still work on this Mac."
    }

    var activatingOnThisMac: String {
        isKorean ? "이 Mac에서 활성화하는 중..." : "Activating on this Mac..."
    }

    var preparingSecureCheckout: String {
        isKorean ? "안전한 결제 세션을 준비하는 중..." : "Preparing a secure checkout session..."
    }

    var checkoutOpenedInBrowser: String {
        isKorean ? "브라우저에서 결제를 열었어요. 완료되면 자동으로 Pro를 이어서 활성화할게요." : "Checkout opened in your browser. Charge Cat will try to finish Pro activation automatically when payment completes."
    }

    var waitingForCheckoutCompletion: String {
        isKorean ? "결제 완료를 기다리는 중..." : "Waiting for checkout to complete..."
    }

    var finishingCheckoutActivation: String {
        isKorean ? "결제 확인 후 Pro 활성화를 마무리하는 중..." : "Payment confirmed. Finishing Pro activation..."
    }

    func proActivatedFromCheckout(productName: String) -> String {
        isKorean
            ? "\(productName) 결제가 확인되어 이 Mac에서 자동으로 활성화됐어요."
            : "\(productName) was confirmed and unlocked automatically on this Mac."
    }

    var checkoutBackendUnavailable: String {
        isKorean ? "이 빌드에는 앱 연동 결제 백엔드가 아직 연결되지 않았어요." : "This build does not have the app-linked checkout backend configured yet."
    }

    var checkoutSessionExpired: String {
        isKorean ? "결제 세션이 만료됐어요. 다시 Pro 구매하기를 눌러 새로 시작해 주세요." : "This checkout session expired. Start a fresh Pro checkout to continue."
    }

    var checkoutStillWaiting: String {
        isKorean ? "결제가 끝났다면 Charge Cat을 다시 열어 주세요. 계속 확인 중이에요." : "If payment is already finished, reopen Charge Cat and it will keep checking."
    }

    var alreadyUnlockedOnThisMac: String {
        isKorean ? "이 Mac은 이미 Pro가 열려 있어서 추가 활성화는 건너뛰었어요." : "This Mac is already unlocked for Pro, so Charge Cat skipped another activation."
    }

    var refreshingProStatus: String {
        isKorean ? "Pro 상태를 확인하는 중..." : "Refreshing Pro status..."
    }

    var proUpToDate: String {
        isKorean ? "Pro 상태가 최신이에요." : "Pro is up to date."
    }

    var removingThisMacFromLemon: String {
        isKorean ? "Lemon에서 이 Mac을 제거하는 중..." : "Removing this Mac from Lemon..."
    }

    var removedThisMacFromPro: String {
        isKorean ? "이 Mac이 Pro 라이선스에서 제거됐어요." : "This Mac was removed from the Pro license."
    }

    var notYet: String { isKorean ? "아직 없음" : "Not yet" }

    var coreFeaturesStayFree: String {
        isKorean
            ? "기본 기능은 계속 무료예요. Pro가 필요하면 결제 후 바로 이 Mac에서 활성화할 수 있어요."
            : "Core features stay free. When you're ready for Pro, buy it first and unlock it on this Mac right away."
    }

    func fullyVerified(productName: String) -> String {
        isKorean
            ? "이 Mac은 \(productName) 검증이 완료됐어요."
            : "This Mac is fully verified for \(productName)."
    }

    var cachedProSummary: String {
        isKorean
            ? "마지막 성공 검증을 바탕으로 Pro를 유지하고, 백그라운드에서 다시 확인하고 있어요."
            : "Pro stays unlocked from the last successful check while Charge Cat retries in the background."
    }

    var revokedProSummary: String {
        isKorean
            ? "이 Mac에 저장된 Pro 활성화가 더 이상 유효하지 않아요."
            : "This saved Pro activation is no longer valid."
    }

    var invalidProSummary: String {
        isKorean
            ? "저장된 라이선스 키를 다시 확인해야 Pro를 열 수 있어요."
            : "The saved license key needs attention before Pro can unlock again."
    }

    func duplicateTriggerMessage(for kind: OverlayEventKind) -> String {
        isKorean
            ? "\(title(for: kind)) 중복 트리거를 막기 위해 무시했어요."
            : "\(title(for: kind)) ignored to avoid a duplicate trigger."
    }

    func triggerMessage(
        kind: OverlayEventKind,
        source: String,
        level: Int,
        side: ScreenSide,
        asset: OverlayAnimationAsset
    ) -> String {
        if isKorean {
            return "\(localizedSource(source)) · \(level)% · \(title(for: kind)) · \(title(for: side)) · \(title(for: asset))"
        }
        return "\(title(for: kind)) from \(localizedSource(source)) at \(level)% on the \(title(for: side).lowercased()) side with \(title(for: asset))."
    }

    func localizedSource(_ source: String) -> String {
        switch source {
        case "system":
            return isKorean ? "시스템" : "system"
        case "menu bar preview":
            return isKorean ? "메뉴 막대 미리보기" : "menu bar preview"
        case "preview":
            return isKorean ? "미리보기" : "preview"
        default:
            return source
        }
    }

    func menuBarStatus(level: Int, powerText: String, powerMode: PowerMode) -> String {
        if isKorean {
            return "배터리 \(level)% • \(powerText) • \(title(for: powerMode))"
        }
        return "Battery \(level)% • \(powerText) • \(title(for: powerMode))"
    }

    func batteryUnavailable(powerMode: PowerMode) -> String {
        if isKorean {
            return "배터리 정보를 읽지 못함 • \(title(for: powerMode))"
        }
        return "Battery unavailable • \(title(for: powerMode))"
    }

    var openSettings: String { isKorean ? "설정 열기" : "Open Settings" }
    var previewAnimation: String { isKorean ? "미리보기 재생" : "Preview Animation" }
    var quit: String { isKorean ? "종료" : "Quit" }
    func powerModeMenuTitle(for mode: PowerMode) -> String {
        isKorean ? "전원 모드 • \(title(for: mode))" : "Power Mode • \(title(for: mode))"
    }

    func title(for side: ScreenSide) -> String {
        switch side {
        case .left:
            return isKorean ? "왼쪽" : "Left"
        case .right:
            return isKorean ? "오른쪽" : "Right"
        }
    }

    func title(for asset: OverlayAnimationAsset) -> String {
        switch asset {
        case .catDoor:
            return isKorean ? "문 고양이" : "Door Cat"
        case .fullBelly:
            return isKorean ? "배부른 고양이" : "Full Belly"
        }
    }

    func title(for event: OverlayEventKind) -> String {
        switch event {
        case .chargeStarted:
            return isKorean ? "충전 시작" : "Charge Start"
        case .fullyCharged:
            return isKorean ? "완충" : "Fully Charged"
        }
    }

    func title(for powerMode: PowerMode) -> String {
        switch powerMode {
        case .lowPower:
            return isKorean ? "절전" : "Low Power"
        case .automatic:
            return isKorean ? "자동" : "Automatic"
        case .highPower:
            return isKorean ? "고성능" : "High Power"
        case .unknown:
            return isKorean ? "알 수 없음" : "Unknown"
        }
    }

    func powerText(for snapshot: BatterySnapshot) -> String {
        if snapshot.isPluggedIn && snapshot.level >= 99 && snapshot.isCharging == false {
            return isKorean ? "완충" : "Fully Charged"
        }
        if snapshot.isCharging {
            return isKorean ? "충전 중" : "Charging"
        }
        if snapshot.isPluggedIn {
            return isKorean ? "전원 연결됨" : "Power Connected"
        }
        return isKorean ? "배터리 사용 중" : "On Battery"
    }

    func title(for status: LicenseStatus) -> String {
        switch status {
        case .free:
            return isKorean ? "무료" : "Free"
        case .proVerified:
            return isKorean ? "Pro 확인됨" : "Pro Verified"
        case .proCached:
            return isKorean ? "Pro 유지 중" : "Pro Cached"
        case .revoked:
            return isKorean ? "해지됨" : "Revoked"
        case .invalid:
            return isKorean ? "유효하지 않음" : "Invalid"
        }
    }

    func title(for warning: LicenseWarningState) -> String {
        switch warning {
        case .none:
            return ""
        case .validationStale:
            return isKorean
                ? "오랫동안 Pro를 다시 확인하지 못했어요. 기능은 유지되지만 가능할 때 인터넷에 다시 연결해 주세요."
                : "Couldn't re-verify Pro for a while. Charge Cat stays unlocked, but please reconnect when you can."
        }
    }

    func followMacOSSetting(limit: Int?) -> String {
        if let limit {
            return isKorean ? "macOS 설정 따라가기 (\(limit)%)" : "Follow macOS setting (\(limit)%)"
        }
        return isKorean ? "macOS 설정 따라가기" : "Follow macOS setting"
    }

    func catWillCheer(at level: Int) -> String {
        isKorean ? "고양이가 \(level)%에서 축하해요." : "Cat will cheer at \(level)%."
    }

    var couldntReadSystemLimit: String {
        isKorean ? "시스템 제한을 읽지 못해 100%로 표시합니다." : "Couldn't read the system limit — falling back to 100%."
    }

    var proCheckoutNotConfigured: String {
        isKorean ? "이 빌드에는 Pro 결제가 아직 연결되지 않았어요." : "Pro checkout isn't configured in this build yet."
    }

    var noSavedProLicense: String {
        isKorean ? "이 Mac에 저장된 Pro 라이선스를 찾지 못했어요." : "No saved Pro license was found on this Mac."
    }

    var licenseKeyFormatWrong: String {
        isKorean
            ? "라이선스 키 형식이 올바르지 않아 보여요. Lemon Squeezy에서 받은 전체 키를 붙여 넣어 주세요."
            : "License key format looks wrong. Paste the full key from Lemon Squeezy."
    }

    var lemonIncompleteActivation: String {
        isKorean ? "Lemon이 활성화 응답을 완전히 돌려주지 않았어요." : "Lemon returned an incomplete activation response."
    }

    var licenseServiceWentAway: String {
        isKorean ? "라이선스 서비스가 중간에 종료됐어요." : "License service went away."
    }

    var lemonCouldNotDeactivateThisMac: String {
        isKorean ? "Lemon에서 지금 이 Mac을 비활성화하지 못했어요." : "Lemon couldn't deactivate this Mac right now."
    }

    var lemonCouldNotVerifyLicense: String {
        isKorean ? "Lemon이 지금 라이선스를 확인하지 못했어요." : "Lemon couldn't verify this license right now."
    }

    var lemonIncompleteValidation: String {
        isKorean ? "Lemon이 검증 응답을 완전히 돌려주지 않았어요." : "Lemon returned an incomplete validation response."
    }

    var activationRejected: String {
        isKorean ? "이 Mac에서 해당 라이선스 키를 활성화할 수 없어요." : "That license key couldn't be activated on this Mac."
    }

    var proLicenseNoLongerValid: String {
        isKorean ? "이 Pro 라이선스는 더 이상 유효하지 않아요." : "This Pro license is no longer valid."
    }

    var proLicenseCouldNotBeFound: String {
        isKorean ? "이 Pro 라이선스를 찾지 못했어요." : "This Pro license couldn't be found."
    }

    var proLicenseNoLongerActive: String {
        isKorean ? "이 Pro 라이선스는 더 이상 활성 상태가 아니에요." : "This Pro license is no longer active."
    }

    var differentLemonProduct: String {
        isKorean ? "이 라이선스는 다른 Lemon 상품에 속해 있어요." : "This license belongs to a different Lemon product."
    }

    var differentProduct: String {
        isKorean ? "이 라이선스는 다른 상품용이에요." : "This license belongs to a different product."
    }

    var savedActivationMismatch: String {
        isKorean
            ? "이 Mac에 저장된 활성화 정보가 Lemon의 기록과 맞지 않아요."
            : "The saved activation on this Mac no longer matches Lemon's record."
    }

    var savedActivationMissing: String {
        isKorean
            ? "이 Mac에 저장된 활성화 정보를 Lemon에서 더 이상 찾을 수 없어요."
            : "The saved activation on this Mac could not be found anymore."
    }

    var licenseKeyInvalidForActivation: String {
        isKorean ? "이 라이선스 키는 활성화에 사용할 수 없어요." : "That license key isn't valid for activation."
    }

    var invalidNetworkResponse: String {
        isKorean ? "Lemon이 올바르지 않은 네트워크 응답을 보냈어요." : "Lemon returned an invalid network response."
    }

    var rateLimitedRetrySoon: String {
        isKorean ? "검증 요청이 잠시 많았어요. Charge Cat이 곧 다시 시도할게요." : "Too many validation checks in a row. Charge Cat will try again shortly."
    }

    var lemonHavingMoment: String {
        isKorean ? "Lemon 쪽이 잠시 불안정해요. Charge Cat이 자동으로 다시 시도할게요." : "Lemon is having a moment. Charge Cat will retry automatically."
    }

    var lemonRejectedRequest: String {
        isKorean ? "Lemon이 이 요청을 거절했어요." : "Lemon rejected this request."
    }

    var couldntReachLemon: String {
        isKorean ? "지금은 Lemon에 연결할 수 없어요." : "Charge Cat couldn't reach Lemon right now."
    }
}
