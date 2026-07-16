# Mac App Store 배포

Charge Cat은 기존 Swift Package/DMG 배포를 유지하면서 `ChargeCat.xcodeproj`를 Mac App Store 전용 타깃으로 사용한다. 이 타깃은 App Sandbox와 Hardened Runtime을 켜고, 원격 애셋을 위한 아웃바운드 네트워크 권한만 선언한다.

## 빌드 구성

- Bundle ID: `com.coldmans.charge-cat`
- Team ID: `2CAPC352DD`
- Category: Utilities
- Minimum macOS: 14.0
- Architectures: Apple Silicon + Intel
- Entitlements: App Sandbox, Outgoing Network Client
- Privacy manifest: `Sources/ChargeCat/Resources/PrivacyInfo.xcprivacy`
- Privacy policy: `https://coldmans.github.io/chargeCat/privacy.html`
- Support URL: `https://github.com/coldmans/chargeCat/issues`

App Store 타깃은 `APP_STORE` 컴파일 조건을 사용한다. 이 빌드에서는 샌드박스 밖의 `/usr/bin/pmset`을 실행하지 않고 `ProcessInfo`가 제공하는 저전력 모드 상태만 표시한다.

## 최초 1회 설정

1. Apple Developer에서 `com.coldmans.charge-cat` explicit App ID를 등록한다.
2. App Store Connect에서 macOS 앱 레코드를 만든다. 이름은 `Charge Cat`, SKU는 `charge-cat-macos`를 권장한다.
3. 계약 상태를 확인하고 가격을 무료로 지정한다.
4. App Privacy는 현재 빌드 기준 `데이터를 수집하지 않음`으로 답하고 개인정보 처리방침 URL을 입력한다.
5. 지원 URL, 설명, 키워드, 저작권, 연령 등급과 실제 앱 화면 스크린샷을 입력한다.

Xcode 자동 서명을 쓰려면 Apple 계정에 해당 Team 권한이 있어야 한다. 이 저장소에서는 2026년 7월 16일 cloud-managed signing으로 Store provisioning profile과 `Mac Installer Distribution` 패키지 서명이 자동 생성되는 것까지 확인했다.

## 로컬 검증

서명 없이 App Store 타깃 자체를 확인한다.

```bash
xcodebuild \
  -project ChargeCat.xcodeproj \
  -scheme ChargeCat \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

계정 변경 없이 서명된 아카이브까지만 만들려면 다음처럼 실행한다.

```bash
EXPORT_APP_STORE=0 ALLOW_PROVISIONING_UPDATES=0 \
  ./scripts/build-app-store.sh 1.0.0 1
```

## 제출 패키지 생성

App ID와 App Store Connect 레코드가 준비된 뒤 실행한다.

```bash
./scripts/build-app-store.sh 1.0.0 1
```

성공하면 `dist/app-store/` 아래에 `.xcarchive`와 App Store용 `.pkg`가 생성된다. 동일한 버전의 재빌드는 build number를 올려야 한다.

생성한 `.pkg`는 Transporter에 드래그하거나 Xcode Organizer에서 업로드한다. 업로드 전에 App Store Connect 앱 레코드가 먼저 존재해야 하며, 업로드가 끝난 뒤 처리 완료된 빌드를 버전 페이지에서 선택해 심사에 제출한다.

## 심사 메모 초안

```text
Charge Cat is a menu bar utility. It reads battery charging state locally with Apple's IOKit power-source API and shows a short visual overlay when power events occur. The app has no account, analytics, advertising, payment, or license flow. Launch at Login is disabled by default and changes only after explicit user action. The current App Store build does not connect to a remote animation catalog.
```
