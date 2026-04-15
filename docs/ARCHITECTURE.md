# Charge Cat — Architecture

## 1. Project Structure

```
chargeCat/
├── Package.swift
├── Sources/
│   └── ChargeCat/
│       ├── App/
│       │   ├── ChargeCatApp.swift          # @main 진입점, NSApplicationDelegateAdaptor
│       │   ├── AppDelegate.swift           # StatusBar, 윈도우 관리, 메뉴 구성
│       │   └── AppModel.swift              # 앱 전체 상태 (@Observable)
│       │
│       ├── Battery/
│       │   ├── BatteryMonitor.swift         # IOKit 기반 충전 이벤트 감지
│       │   └── BatterySnapshot.swift        # 배터리 상태 데이터 (struct, immutable)
│       │
│       ├── Overlay/
│       │   ├── OverlayWindowController.swift  # NSPanel 생성/위치/표시 관리
│       │   ├── OverlayContainerView.swift     # 애니메이션 시퀀스 실행 (SwiftUI)
│       │   └── OverlayPayload.swift           # 오버레이 표시 데이터 (struct)
│       │
│       ├── Animation/
│       │   ├── AnimationType.swift           # enum: bow, stretch, yawn, celebrate
│       │   ├── AnimationSequencer.swift       # 타입별 애니메이션 시퀀스 실행
│       │   └── AnimationPicker.swift          # 랜덤 선택 로직
│       │
│       ├── Cat/
│       │   ├── CatCharacterView.swift        # 고양이 전체 조립 뷰
│       │   ├── CatHeadView.swift             # 머리 (귀, 눈, 코, 입)
│       │   ├── CatBodyView.swift             # 몸통 (배, 발)
│       │   ├── CatTailView.swift             # 꼬리 Shape
│       │   ├── CatCondition.swift            # enum: low, regular, full
│       │   └── CatExpressions.swift          # 표정 파라미터 (smile, eye shape 등)
│       │
│       ├── Door/
│       │   ├── DoorSceneView.swift           # 문틀 + 포탈 + 문짝 + 그림자 조립
│       │   ├── DoorPanelView.swift           # 문짝 (3D 회전)
│       │   └── PortalGlowView.swift          # 문 뒤 빛 효과
│       │
│       ├── Panel/
│       │   ├── ControlPanelView.swift        # 설정 패널 메인 뷰
│       │   ├── ControlWindowController.swift # NSWindow 래퍼
│       │   ├── CornerPreviewView.swift       # 미니 화면 목업 프리뷰
│       │   ├── ControlsSection.swift         # 컨트롤 영역 (토글, 슬라이더, 버튼)
│       │   └── LiveStatusSection.swift       # 배터리 상태 표시
│       │
│       ├── Onboarding/
│       │   ├── OnboardingView.swift          # 최초 실행 온보딩 뷰
│       │   └── OnboardingWindowController.swift
│       │
│       ├── Sound/
│       │   └── SoundPlayer.swift             # 사운드 재생 (NSSound)
│       │
│       ├── Settings/
│       │   ├── UserSettings.swift            # @AppStorage 기반 설정 저장
│       │   └── LaunchAtLogin.swift           # SMAppService 래퍼
│       │
│       ├── Shared/
│       │   ├── ScreenSide.swift              # enum: left, right
│       │   ├── Palette.swift                 # 컬러 상수 정의
│       │   ├── Shapes.swift                  # Triangle, SmileShape 등 커스텀 Shape
│       │   └── ButtonStyles.swift            # Primary, Secondary 버튼 스타일
│       │
│       └── Resources/
│           ├── Assets.xcassets/              # 앱 아이콘, 메뉴바 아이콘
│           └── Sounds/
│               ├── door-creak.aiff
│               ├── cat-chirp.aiff
│               └── sparkle.aiff
│
├── docs/
│   ├── PRD.md
│   ├── DESIGN.md
│   └── ARCHITECTURE.md
│
├── scripts/
│   └── build-release.sh
│
├── Casks/
│   └── charge-cat.rb
│
└── index.html                              # 랜딩 페이지
```

---

## 2. Module Dependency Graph

```
ChargeCatApp
    ├── AppDelegate
    │   ├── AppModel ◄─── 핵심 상태 허브
    │   │   ├── UserSettings
    │   │   └── OverlayPayload
    │   ├── BatteryMonitor
    │   │   └── BatterySnapshot
    │   ├── OverlayWindowController
    │   │   └── OverlayContainerView
    │   │       ├── AnimationSequencer
    │   │       │   └── AnimationType
    │   │       ├── DoorSceneView
    │   │       ├── CatCharacterView
    │   │       └── SoundPlayer
    │   ├── ControlWindowController
    │   │   └── ControlPanelView
    │   └── OnboardingWindowController (최초 실행 시)
    │       └── OnboardingView
    │
    Shared (모든 모듈에서 사용)
    ├── Palette
    ├── ScreenSide
    ├── Shapes
    └── ButtonStyles
```

**의존 방향:** 위 → 아래. 역방향 의존 없음.

---

## 3. State Management

### 3.1 AppModel (핵심 상태 허브)

```swift
@MainActor @Observable
final class AppModel {
    // ── 사용자 설정 (UserSettings에서 로드/저장) ──
    var preferredSide: ScreenSide = .left
    var soundEnabled: Bool = true
    var autoMonitorEnabled: Bool = true
    var launchAtLoginEnabled: Bool = false

    // ── 런타임 상태 ──
    var previewBatteryLevel: Double = 38
    var latestBattery: BatterySnapshot?
    var lastEventDescription: String = "Ready"

    // ── 내부 상태 (throttle) ──
    private var lastTriggerAt: Date?
    private var lastTriggerKind: OverlayEventKind?

    // ── 의존성 ──
    private weak var overlayPresenter: OverlayPresenting?

    func trigger(_ kind: OverlayEventKind, level: Int?, source: String)
    func updateBattery(_ snapshot: BatterySnapshot?)
}
```

### 3.2 UserSettings (영속 저장)

```swift
struct UserSettings {
    // @AppStorage 기반, UserDefaults에 저장
    static var preferredSide: ScreenSide      // "preferredSide"
    static var soundEnabled: Bool             // "soundEnabled", default: true
    static var autoMonitorEnabled: Bool       // "autoMonitorEnabled", default: true
    static var launchAtLoginEnabled: Bool     // "launchAtLoginEnabled", default: false
    static var hasCompletedOnboarding: Bool   // "hasCompletedOnboarding", default: false
}
```

### 3.3 데이터 흐름

```
[IOKit 전원 이벤트]
    │
    ▼
BatteryMonitor.poll()
    │
    ├── AppModel.updateBattery(snapshot)     ← 상태 업데이트
    │
    └── AppModel.trigger(.chargeStarted)     ← 이벤트 트리거
            │
            ├── throttle 체크 (10초)
            ├── AnimationPicker.select(for:)  ← 애니메이션 타입 결정
            │
            ▼
        OverlayPresenter.present(payload)
            │
            ├── NSPanel 위치 설정
            ├── OverlayContainerView 렌더
            │   ├── AnimationSequencer 실행
            │   └── SoundPlayer 재생
            │
            └── 완료 후 panel.orderOut
```

---

## 4. Key Protocols

```swift
/// 오버레이 표시를 추상화. 테스트 시 mock 가능.
@MainActor
protocol OverlayPresenting: AnyObject {
    func present(payload: OverlayPayload)
}

/// 사운드 재생을 추상화.
protocol SoundPlaying {
    func play(_ sound: SoundEffect)
    var isEnabled: Bool { get set }
}

/// 애니메이션 시퀀스 실행.
@MainActor
protocol AnimationSequencing {
    func run(type: AnimationType, payload: OverlayPayload) async
}
```

---

## 5. Key Data Types

```swift
// 배터리 상태 스냅샷 (immutable)
struct BatterySnapshot: Equatable {
    let level: Int           // 0~100
    let isPluggedIn: Bool
    let isCharging: Bool
}

// 오버레이 표시 데이터 (immutable)
struct OverlayPayload: Identifiable, Equatable {
    let id: UUID
    let kind: OverlayEventKind
    let batteryLevel: Int
    let side: ScreenSide
    let animationType: AnimationType
}

// 충전 이벤트 종류
enum OverlayEventKind: String {
    case chargeStarted
    case fullyCharged
}

// 화면 위치
enum ScreenSide: String, CaseIterable, Identifiable {
    case left, right
}

// 고양이 컨디션
enum CatCondition {
    case low       // ≤20%
    case regular   // 21~79%
    case full      // ≥80% or fullyCharged
}

// 애니메이션 타입
enum AnimationType {
    case bow        // 인사
    case stretch    // 기지개
    case yawn       // 하품
    case celebrate  // 완충 축하
}

// 사운드 효과
enum SoundEffect: String {
    case doorCreak = "door-creak"
    case catChirp = "cat-chirp"
    case sparkle = "sparkle"
}
```

---

## 6. Build & Package

### Package.swift
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChargeCat",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ChargeCat", targets: ["ChargeCat"])
    ],
    targets: [
        .executableTarget(name: "ChargeCat")
    ]
)
```

### 외부 의존성: 없음
- IOKit: 시스템 프레임워크 (별도 import만)
- AppKit/SwiftUI: 시스템 프레임워크
- ServiceManagement (SMAppService): 시스템 프레임워크

---

## 7. Concurrency Model

- **모든 UI 코드:** `@MainActor`
- **BatteryMonitor:** `@MainActor` (IOKit 콜백은 `Task { @MainActor }` 로 디스패치)
- **애니메이션 시퀀스:** `async`/`await` + `Task.sleep` (메인 스레드에서 실행)
- **사운드 재생:** 메인 스레드 (`NSSound.play()`)
- **GCD/DispatchQueue 사용 안 함** — Swift Concurrency만 사용

---

## 8. MVP → Production 마이그레이션 가이드

기존 MVP (`charge-cat-mvp/`)에서 가져올 것:

| MVP 파일 | Production 위치 | 변경 사항 |
|---------|----------------|----------|
| `ChargeCatMVPApp.swift` | `App/ChargeCatApp.swift` + `App/AppDelegate.swift` | 분리, 이름 변경 |
| `AppModel.swift` (AppModel) | `App/AppModel.swift` | @Observable로 전환, UserSettings 연동 |
| `AppModel.swift` (BatteryMonitor) | `Battery/BatteryMonitor.swift` | 별도 파일로 분리 |
| `AppModel.swift` (BatterySnapshot) | `Battery/BatterySnapshot.swift` | 별도 파일로 분리 |
| `AppModel.swift` (enums) | `Shared/ScreenSide.swift`, `Cat/CatCondition.swift` 등 | 각각 분리 |
| `Views.swift` (전체) | `Panel/`, `Cat/`, `Door/`, `Overlay/`, `Shared/` | 뷰별 분리 |

**핵심 원칙:** MVP의 로직은 검증됨. 구조만 분리하고, 새 기능(사운드, 애니메이션 변형, 온보딩, Launch at Login)을 추가.
