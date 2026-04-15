# Charge Cat — Product Requirements Document

## 1. Product Overview

**한 줄 정의:** 맥북 충전기를 꽂으면 화면 구석에서 작은 문이 열리고 고양이가 인사하는 macOS 오버레이 앱.

**핵심 가치:** 충전이라는 평범한 순간을 2초짜리 감정적 보상으로 바꾼다.

**포지셔닝:** 유틸리티가 아니라 리추얼(의식). 생산성 앱이 아니라 감성 앱.

---

## 2. Target User

- macOS 14+ (Sonoma 이상) 맥북 사용자
- 데스크 셋업/감성에 투자하는 20~35세
- 배경화면, 노션 커버, 키캡 등 비기능적 꾸미기에 기꺼이 지출하는 사람

---

## 3. Core User Flow

```
[충전기 연결] → [이벤트 감지] → [오버레이 윈도우 표시]
→ [문 열림 애니메이션] → [고양이 등장 + 인사]
→ [고양이 퇴장 + 문 닫힘] → [오버레이 사라짐]

전체 시퀀스: ~2.5초
```

---

## 4. Feature Specification

### 4.1 Must Have (v1.0 출시 필수)

#### F-01: 충전 이벤트 감지
- IOKit `IOPSNotificationCreateRunLoopSource`로 전원 상태 변경 감지
- 15초 간격 폴링 fallback
- 감지 이벤트: 충전 시작 (`chargeStarted`), 완충 (`fullyCharged`)
- 10초 쿨다운 (동일 이벤트 중복 방지)

#### F-02: 오버레이 윈도우
- `NSPanel` (borderless, nonactivating)
- 화면 좌하단 또는 우하단에 표시
- 다른 앱 위에 표시 (`level: .statusBar`)
- 마우스 이벤트 무시 (`ignoresMouseEvents: true`)
- 모든 Space에서 표시 (`canJoinAllSpaces`)
- 전체화면 앱 위에서도 표시 가능 (`fullScreenAuxiliary`)
- 크기: 300 x 220pt
- 화면 가장자리에서 18pt 여백

#### F-03: 고양이 애니메이션 시퀀스
- 3종 이상의 애니메이션 랜덤 재생 (매번 같으면 질림)
- 배터리 잔량에 따른 고양이 컨디션 분기:
  - `low` (≤20%): 지친 표정, 작은 몸
  - `regular` (21~79%): 보통 표정, 중간 몸
  - `full` (≥80% 또는 fullyCharged): 기쁜 표정, 큰 몸
- 애니메이션 타이밍: 총 ~2.5초
- 상세 시퀀스는 DESIGN.md 참조

#### F-04: 메뉴바 상주
- `NSApp.setActivationPolicy(.accessory)` — Dock 아이콘 없음
- 메뉴바 아이콘 (커스텀 아이콘, 이모지 아님)
- 메뉴 항목:
  - Open Settings (설정 패널 열기)
  - Preview Animation (수동 재생)
  - Quit

#### F-05: 설정 패널 (Control Panel)
- 오버레이 위치: 좌/우 선택 (Segmented Picker)
- 사운드 on/off 토글
- 자동 감지 on/off 토글
- 프리뷰 배터리 레벨 슬라이더
- "Play Charge Start" / "Play Full Charge" 버튼
- 현재 배터리 상태 표시

#### F-06: Launch at Login
- `SMAppService`로 로그인 시 자동 시작
- 설정 패널에서 on/off 토글

#### F-07: 사운드 이펙트
- 문 열리는 소리 (짧은 삐걱)
- 고양이 인사 소리 (작은 야옹 또는 방울 소리)
- 시스템 볼륨 연동
- 전체 뮤트 토글 (설정 패널)
- 오디오 파일: `.aiff` 또는 `.mp3`, 각 0.5초 이하

#### F-08: 앱 아이콘
- macOS 규격 앱 아이콘 (1024x1024 기본)
- 메뉴바용 템플릿 아이콘 (18x18 @1x, 36x36 @2x)

### 4.2 Should Have (v1.0에 가능하면)

#### F-09: 충전 완료 전용 애니메이션
- `fullyCharged` 이벤트에 별도 애니메이션 세트
- 고양이가 기뻐하는 모션 (왕관, 반짝임 등)

#### F-10: Do Not Disturb 연동
- macOS 집중 모드 활성화 시 오버레이 비표시
- 전체화면 앱 실행 중 비표시 옵션

#### F-11: 온보딩
- 최초 실행 시 1페이지 온보딩
- "충전기를 꽂아보세요!" 안내
- Launch at Login 권한 요청

### 4.3 Nice to Have (v1.1+)

#### F-12: 추가 고양이 캐릭터/스킨
- 유료 업그레이드로 잠금 해제
- v1.1에서 2~3마리 추가

#### F-13: 계절/시간대별 문 디자인
- 아침/저녁 색상 변화
- 계절별 데코레이션

#### F-14: 충전 통계
- 일일/주간 충전 횟수
- 고양이 인사 횟수 카운터

#### F-15: GIF 익스포트
- 현재 애니메이션을 GIF로 저장
- 소셜 공유 용도

---

## 5. Monetization

### v1.0: 완전 무료
- 모든 기본 기능 무료 제공
- 바이럴 확산 우선

### v1.1+: 유료 업그레이드 ($3.99 일회성)
무료:
- 기본 고양이 1마리
- 충전 시작 애니메이션 3종 랜덤
- 좌/우 위치 선택
- 사운드 on/off

유료 잠금 해제:
- 추가 애니메이션 (3~5종)
- 충전 완료 전용 애니메이션
- 추가 고양이 캐릭터
- 향후 업데이트 포함

---

## 6. Distribution

- **Primary:** GitHub Releases (.dmg 직접 다운로드)
- **Secondary:** Homebrew Cask (`brew install --cask charge-cat`)
- **Landing page:** GitHub Pages (`coldmans.github.io/chargeCat`)
- **No App Store** (심사 리스크 회피, 수수료 절감)

---

## 7. Technical Constraints

- Swift 6.2+ / macOS 14+ (Sonoma)
- SwiftUI + AppKit hybrid (오버레이는 AppKit NSPanel 필수)
- 서버 없음 (완전 로컬)
- 외부 의존성 없음 (Swift Package Manager, 서드파티 라이브러리 0)
- 유휴 시 CPU 사용 ~0% (IOKit 콜백 기반, 타이머는 15초 간격 fallback)
- 메모리 < 30MB

---

## 8. Out of Scope (절대 넣지 않을 것)

- 클라우드 동기화
- 사용자 계정/로그인
- 알림 센터 연동
- 배터리 잔량 표시 위젯 (macOS 기본 기능과 겹침)
- Windows/Linux 지원
- iOS 버전
