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
    var animationByEvent: String { isKorean ? "이벤트별 애니메이션" : "Animations by Event" }
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

    var support: String { isKorean ? "지원" : "Support" }
    var privacyPolicy: String { isKorean ? "개인정보 처리방침" : "Privacy Policy" }
    var status: String { isKorean ? "상태" : "Status" }
    var noneOnThisMac: String { isKorean ? "이 Mac에는 없음" : "None on this Mac" }
    var notSaved: String { isKorean ? "저장 안 함" : "Not saved" }

    var downloadableAnimations: String {
        isKorean ? "추가 애니메이션 팩" : "Extra Animation Packs"
    }

    var downloadableAssetsNotConfigured: String {
        isKorean ? "추가 애니메이션 목록이 아직 연결되지 않았어요." : "The extra animation catalog is not connected yet."
    }

    var noDownloadableAnimationsYet: String {
        isKorean ? "아직 내려받을 수 있는 추가 애니메이션이 없어요." : "No extra animations are available to download yet."
    }

    var installedBadge: String { isKorean ? "설치됨" : "Installed" }
    var bundledBadge: String { isKorean ? "기본 포함" : "Included" }
    var download: String { isKorean ? "다운로드" : "Download" }
    var delete: String { isKorean ? "삭제" : "Delete" }
    var refreshCatalog: String { isKorean ? "목록 새로고침" : "Refresh Catalog" }

    var loadingAnimationCatalog: String {
        isKorean ? "애니메이션 목록을 불러오는 중..." : "Loading animation catalog..."
    }

    func downloadingAnimation(name: String) -> String {
        isKorean ? "\(name) 다운로드 중..." : "Downloading \(name)..."
    }

    func downloadedAnimation(name: String) -> String {
        isKorean ? "\(name) 애니메이션을 추가했어요." : "Added the \(name) animation."
    }

    func removingAnimation(name: String) -> String {
        isKorean ? "\(name) 삭제 중..." : "Removing \(name)..."
    }

    func removedAnimation(name: String) -> String {
        isKorean ? "\(name) 애니메이션을 삭제했어요." : "Removed the \(name) animation."
    }

    var couldNotLoadAnimationCatalog: String {
        isKorean ? "추가 애니메이션 목록을 불러오지 못했어요." : "Couldn't load the extra animation catalog."
    }

    var couldNotDownloadAnimation: String {
        isKorean ? "애니메이션을 다운로드하지 못했어요." : "Couldn't download this animation."
    }

    var downloadedAnimationMissing: String {
        isKorean ? "다운로드한 애니메이션 파일을 찾지 못했어요." : "A downloaded animation file is missing."
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

    var notYet: String { isKorean ? "아직 없음" : "Not yet" }

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
        assetTitle: String
    ) -> String {
        if isKorean {
            return "\(localizedSource(source)) · \(level)% · \(title(for: kind)) · \(title(for: side)) · \(assetTitle)"
        }
        return "\(title(for: kind)) from \(localizedSource(source)) at \(level)% on the \(title(for: side).lowercased()) side with \(assetTitle)."
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

    func catWillCheer(at level: Int) -> String {
        isKorean ? "고양이가 \(level)%에서 축하해요." : "Cat will cheer at \(level)%."
    }
}
