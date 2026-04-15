# Charge Cat — Design Specification

## 1. Design Principles

1. **Warm, not cute-sy** — 감성적이되 유치하지 않게. 성인이 쓰기 부끄럽지 않은 톤.
2. **Tiny and respectful** — 화면을 방해하지 않는다. 작고, 빠르고, 조용하다.
3. **Surprise over utility** — 항상 보이는 게 아니라, 특정 순간에만 나타나서 특별하다.

---

## 2. Color Palette

앱 전체에서 사용하는 컬러 시스템. 따뜻하고 아늑한 톤.

| Token | Hex | RGB | 용도 |
|-------|-----|-----|------|
| `ink` | `#2E2621` | (46, 38, 33) | 텍스트, 주요 콘텐츠 |
| `cream` | `#FAF3E6` | (250, 243, 230) | 배경 보조 |
| `paper` | `#FCF7F0` | (252, 247, 240) | 배경 메인 |
| `peach` | `#F5CEAF` | (245, 206, 175) | 고양이 배 부분, 강조 보조 |
| `amber` | `#ED9E4F` | (237, 158, 79) | 고양이 몸통, 문, CTA 버튼 |
| `coral` | `#E3755F` | (227, 117, 95) | 문 그라데이션, 경고, 액센트 |
| `cocoa` | `#664229` | (102, 66, 41) | 고양이 눈/코/꼬리/발, 문틀 |
| `shadow` | `#000000` 16% | - | 그림자 |
| `screen` | `#242830` | (36, 40, 48) | 프리뷰 배경 (다크) |
| `screenEdge` | `#3B424F` | (59, 66, 79) | 프리뷰 테두리 |

---

## 3. Typography

시스템 폰트 사용 (SF Pro). 외부 폰트 로드 없음.

| 스타일 | Font | Size | Weight | Design |
|--------|------|------|--------|--------|
| Title | System | 30 | Black (.black) | Rounded |
| Section Header | System | 15 | Bold | Rounded |
| Body | System | 13 | Semibold | Rounded |
| Caption | System | 12 | Semibold | Rounded |
| Badge | System | 11 | Bold | Rounded |

**모든 텍스트에 `.rounded` 디자인 적용** — 앱의 따뜻한 톤에 맞춤.

---

## 4. View Hierarchy

```
App (NSApp, .accessory policy)
├── StatusBar Item (메뉴바 아이콘)
│   └── NSMenu
│       ├── Open Settings
│       ├── Preview Animation
│       ├── separator
│       └── Quit
│
├── ControlWindow (설정 패널, NSWindow)
│   └── ControlPanelView (SwiftUI)
│       ├── Header (앱 이름, 설명)
│       ├── CornerPreview (미니 화면 목업 + 고양이 프리뷰)
│       ├── Controls
│       │   ├── Side Picker (좌/우)
│       │   ├── Battery Slider (프리뷰용)
│       │   ├── Play Buttons (Charge Start / Full Charge)
│       │   ├── Sound Toggle
│       │   ├── Auto Monitor Toggle
│       │   └── Launch at Login Toggle
│       └── LiveStatus (현재 배터리 상태)
│
└── OverlayPanel (NSPanel, borderless)
    └── OverlayContainerView (SwiftUI)
        └── DoorAndCatScene
            ├── Shadow (바닥 그림자)
            ├── Portal (문 뒤 빛)
            ├── DoorFrame (문틀)
            ├── DoorPanel (여닫이 문)
            └── CatCharacter
                ├── Tail
                ├── Body (torso + belly)
                ├── Paws
                └── Head
                    ├── Ears (L, R)
                    ├── Eyes (L, R)
                    ├── Nose
                    └── Mouth (smile curve)
```

---

## 5. Control Panel Design

### 5.1 Window Properties
- 크기: 460 x 640pt (고정, 리사이즈 불가)
- 스타일: titled, closable, miniaturizable, fullSizeContentView
- 투명 타이틀바 (`titlebarAppearsTransparent`)
- 배경 드래그 가능 (`isMovableByWindowBackground`)
- 배경: `paper → cream → white` 대각선 그라데이션
- 모서리: 시스템 기본 (macOS 윈도우)

### 5.2 Layout (위에서 아래 순서)

#### Header
- "Charge Cat" 제목 (30pt, Black, Rounded)
- 좌측에 버전 뱃지 ("v1.0", 11pt, capsule 배경)
- 아래에 한 줄 설명 (15pt, ink 72% opacity)

#### Corner Preview (미니 화면 목업)
- 다크 배경 (screen → screenEdge 그라데이션)
- 둥근 모서리 28pt
- 좌상단에 세 개 작은 원 (macOS 윈도우 버튼 느낌)
- 하단에 독 바 느낌의 작은 사각형
- 선택된 코너 방향에 맞춰 고양이+문 프리뷰 표시
- 높이: 250pt

#### Controls
- **Side:** Segmented Picker ["Left", "Right"]
- **Preview Battery:** 슬라이더 1~100, 우측에 현재 값 표시
- **Play Charge Start:** Primary 버튼 (amber→coral 그라데이션, 흰색 텍스트, bolt.fill 아이콘)
- **Play Full Charge:** Secondary 버튼 (흰색 배경, ink 텍스트, sparkles 아이콘)
- **Sound:** Toggle (System .switch 스타일)
- **Auto react to real charging events:** Toggle
- **Launch at Login:** Toggle

#### Live Status
- 배터리 상태 뱃지: StatusBadge 컴포넌트 (capsule, 색상 코딩)
  - 충전 중: amber 배경
  - 배터리 사용 중: coral 배경
- 배터리 잔량 뱃지: cocoa 배경
- 마지막 이벤트 설명 텍스트

### 5.3 Button Styles

#### PrimaryActionButtonStyle
```
배경: LinearGradient(amber → coral, leading → trailing)
텍스트: 13pt Bold Rounded, 흰색
패딩: H14 V11
모서리: 14pt continuous
그림자: shadow, radius 12, y 7
누름 시: scale 0.98
```

#### SecondaryActionButtonStyle
```
배경: 흰색 92% opacity (누름 시 72%)
텍스트: 13pt Bold Rounded, ink
패딩: H14 V11
모서리: 14pt continuous
테두리: ink 8% opacity, 1pt
누름 시: scale 0.98
```

---

## 6. Overlay Design

### 6.1 Panel Properties
- 크기: 300 x 220pt
- 스타일: borderless, nonactivatingPanel
- 투명 배경
- 그림자 없음
- 레벨: statusBar
- 마우스 이벤트 무시
- 화면 가장자리에서 18pt 여백
- 모든 Space에서 표시

### 6.2 위치 계산
```
let visibleFrame = NSScreen.main.visibleFrame
let inset: CGFloat = 18

Left:  x = visibleFrame.minX + inset
Right: x = visibleFrame.maxX - panelWidth - inset
Y:     y = visibleFrame.minY + inset
```

---

## 7. Cat Character Design

### 7.1 Condition별 변형

| Property | low (≤20%) | regular (21~79%) | full (≥80%) |
|----------|-----------|-----------------|-------------|
| Body size | 56 x 44 | 68 x 52 | 78 x 62 |
| Head size | 34 | 38 | 40 |
| Ear lift | -2 | 0 | +2 |
| Eye shape | 7x2 (졸린 눈) | 6x4 (동그란 눈) | 6x4 (동그란 눈) |
| Eye rotation | -12deg | 0 | 0 |
| Smile curve | 작음 | 중간 | 크게 |

### 7.2 Cat Anatomy (벡터 구성)

```
[꼬리] - Bezier curve, cocoa 색, stroke 10pt, round cap
  └ 시작: body 우측 하단
  └ S자 커브로 위로 올라감

[몸통] - Ellipse, amber 색
  └ [배] - 내부 Ellipse, peach 색, body의 66% x 56%, y+5 오프셋
  └ [발] - 2개 Capsule, cocoa 색, 12x8, 간격 8

[머리] - Circle, amber 색
  └ [귀 L] - Triangle, amber, -12deg 회전, 좌상단
  └ [귀 R] - Triangle, amber, +12deg 회전, 우상단
  └ [눈 L] - Capsule, cocoa
  └ [눈 R] - Capsule, cocoa
  └ [코] - Circle, cocoa, 4x4
  └ [입] - SmileShape (QuadCurve), cocoa stroke 2.5pt
```

### 7.3 Door Anatomy

```
[바닥 그림자] - Ellipse, shadow 35%, blur 12, 124x24

[포탈 빛] - RoundedRect 18pt, 58x88
  └ 그라데이션: white 18% → amber 75% → coral 65%
  └ portalGlow로 opacity 조절

[문틀] - RoundedRect 18pt, 64x94, cocoa 단색

[문짝] - RoundedRect 16pt, 54x82
  └ 그라데이션: amber 90% → coral 96%
  └ [손잡이] - Circle, cream, 6x6, 우측 중앙
  └ rotation3DEffect로 Y축 회전 (열림/닫힘)
  └ perspective: 0.75
```

---

## 8. Animation Sequences

### 8.1 Type A: "인사" (기본, 가장 자주 재생)

| Phase | Duration | Properties | Easing |
|-------|----------|------------|--------|
| 1. Portal glow | 0ms | portalGlow: 0.25 → 1.0 | spring(0.34, 0.82) |
| 2. Door crack open | 0ms | doorAngle: -90 → -68 | spring(0.34, 0.82) |
| 3. Wait | 180ms | - | - |
| 4. Door open + Cat enter | 180ms | doorAngle → -16, catTravel → 66, bounce → -6 | spring(0.42, 0.76) |
| 5. Wait | 320ms | - | - |
| 6. Bow + Smile | 500ms | bowAngle → 18, smileAmount → 0.26, bounce → 0 | easeInOut(0.16) |
| 7. Wait | 220ms | - | - |
| 8. Bow up | 720ms | bowAngle → 0, bounce → -3, smileAmount → 0.30 | easeInOut(0.16) |
| 9. Wait | 280ms | - | - |
| 10. Cat exit + Door close | 1000ms | catTravel → -8, doorAngle → -78, bounce → 4 | interpolatingSpring(180, 14) |
| 11. Wait | 220ms | - | - |
| 12. Fade out | 1220ms | overlayOpacity → 0 | easeIn(0.22) |
| 13. Wait | 250ms | - | - |
| 14. Dismiss | 1470ms | onFinished() | - |

**Total: ~2.5초**

### 8.2 Type B: "기지개" (랜덤 변형)

| Phase | Duration | Properties | Easing |
|-------|----------|------------|--------|
| 1~4 | 동일 | Door open + Cat enter | 동일 |
| 5. Stretch up | 500ms | bowAngle → -8, bounce → -10, body scaleY → 1.15 | spring(0.5, 0.7) |
| 6. Wait | 400ms | - | - |
| 7. Relax | 900ms | bowAngle → 0, bounce → 0, scaleY → 1.0, smileAmount → 0.32 | easeInOut(0.3) |
| 8~14 | 동일 | Cat exit + Fade out | 동일 |

### 8.3 Type C: "하품" (랜덤 변형)

| Phase | Duration | Properties | Easing |
|-------|----------|------------|--------|
| 1~4 | 동일 | Door open + Cat enter | 동일 |
| 5. Tilt head | 500ms | bowAngle → 5, headTilt → 8deg | easeInOut(0.2) |
| 6. Yawn | 700ms | mouthOpen → 0.6 (입 크게), eyes → squint | easeInOut(0.35) |
| 7. Close mouth | 1050ms | mouthOpen → 0, eyes → normal, smileAmount → 0.28 | easeOut(0.2) |
| 8~14 | 동일 | Cat exit + Fade out | 동일 |

### 8.4 Full Charge 전용: "축하" (F-09)

| Phase | Duration | Properties | Easing |
|-------|----------|------------|--------|
| 1~4 | 동일 | Door open + Cat enter (catTravel → 72) | 동일 |
| 5. Happy jump | 500ms | bounce → -14, smileAmount → 0.38 | spring(0.3, 0.6) |
| 6. Land | 700ms | bounce → 0 | spring(0.35, 0.8) |
| 7. Sparkle | 700ms | 주변에 3~4개 작은 별 파티클 | easeOut(0.5) |
| 8. Wait | 300ms | - | - |
| 9~14 | 동일 | Cat exit + Fade out | 동일 |

### 8.5 Animation Selection Logic
```swift
func selectAnimation(for event: OverlayEventKind) -> AnimationType {
    if event == .fullyCharged {
        return .celebrate  // 항상 축하
    }
    // chargeStarted일 때 랜덤 선택
    let roll = Int.random(in: 0..<10)
    switch roll {
    case 0..<5: return .bow       // 50%
    case 5..<8: return .stretch   // 30%
    default:    return .yawn      // 20%
    }
}
```

---

## 9. Sound Design

| Sound | Trigger | Duration | Style |
|-------|---------|----------|-------|
| `door-creak.aiff` | Phase 2 (문 열릴 때) | ~0.3s | 나무 문 삐걱, 부드럽고 작게 |
| `cat-chirp.aiff` | Phase 6 (인사할 때) | ~0.4s | 짧은 "먀~" 또는 방울 소리 |
| `sparkle.aiff` | Full Charge Phase 7 | ~0.5s | 반짝임 효과음 |

- `NSSound` 또는 `AVAudioPlayer`로 재생
- 시스템 볼륨의 50%로 재생 (너무 크면 놀람)
- 설정에서 전체 뮤트 가능

---

## 10. Onboarding (F-11)

### 최초 실행 시 1페이지

```
┌─────────────────────────────────┐
│                                 │
│      [고양이 일러스트]            │
│                                 │
│   "Charge Cat이 준비됐어요!"     │
│                                 │
│   충전기를 꽂으면 고양이가        │
│   인사하러 나올 거예요.           │
│                                 │
│   ☐ 로그인 시 자동 시작           │
│                                 │
│        [ 시작하기 ]              │
│                                 │
└─────────────────────────────────┘
```

- 단일 페이지, 스크롤 없음
- "시작하기" 누르면 닫히고 메뉴바에 상주
- Launch at Login 체크박스 포함

---

## 11. Menu Bar Icon

- 템플릿 이미지 (macOS 자동 다크/라이트 대응)
- 18x18 @1x, 36x36 @2x
- 고양이 실루엣 (단순한 머리+귀 형태)
- SF Symbols 스타일에 맞는 선 두께

---

## 12. Responsive Behavior

| 상황 | 동작 |
|------|------|
| 외장 모니터 연결 | `NSScreen.main`의 visibleFrame 기준으로 표시 |
| 다중 모니터 | 메인 모니터에만 표시 |
| 전체화면 앱 사용 중 | 표시 (fullScreenAuxiliary). v1.1에서 옵션화 |
| 데스크톱 Mac (배터리 없음) | 프리뷰 버튼만 동작, 자동 감지 비활성화 + 안내 메시지 |
| Sidecar/iPad 디스플레이 | 메인 모니터에만 표시 |

---

## 13. Accessibility

- VoiceOver: 오버레이 애니메이션에 접근성 레이블 불필요 (장식적 요소, `ignoresMouseEvents`)
- Reduce Motion: `@Environment(\.accessibilityReduceMotion)` 감지 시 애니메이션 없이 정적 이미지로 2초 표시 후 사라짐
- 설정 패널: 모든 컨트롤에 적절한 접근성 레이블
