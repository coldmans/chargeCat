# AGENTS.md

이 문서는 Claude Code와 Codex CLI가 이 저장소에서 공동으로 작업할 때 따라야 하는 **불변 규칙과 공통 컨텍스트**를 정의합니다. 에이전트가 새 세션을 시작하면 가장 먼저 이 파일을 읽고 작업에 들어갑니다.

프로젝트 루트: `/Users/coldmans/Documents/GitHub/chargeCat`

---

## 1. 프로젝트 개요

ChargeCat은 맥북 사용자가 충전기를 꽂을 때 화면 구석에 작은 고양이 애니메이션을 띄워주는 macOS 메뉴바 앱입니다. v1.0.1 출시 시점에 Pro 기능(이벤트별 애니메이션 + 다운로드 가능 팩)이 추가되었고, 라이선스/결제를 처리하는 자체 백엔드가 붙었습니다.

구성 요소:

- **macOS 앱 (Swift / SwiftUI)** — `Sources/ChargeCat/`
  - `App/` 앱 상태(`AppModel`), `Battery/` 충전 감지, `Overlay/` 오버레이 표시
  - `Panel/` 제어판 UI, `Animation/` 에셋 로딩·재생, `Licensing/` Lemon/Toss 라이선스
  - `Settings/` UserDefaults 래퍼, `Shared/AppLanguage.swift` 로컬라이제이션
- **백엔드 (Node.js 25 + Express 5)** — `backend/src/`
  - `app.js` 엔드포인트, `database.js` DB 레이어, `lemon-client.js` / `toss-client.js` 결제, `validators.js` zod 스키마, `html.js` 체크아웃 페이지 렌더링
  - 현재 SQLite(`node:sqlite`) 사용 중, MySQL(도커)로 이관 진행 중
- **랜딩 페이지** — 루트 `index.html` (GitHub Pages)
- **배포 자산** — `Casks/charge-cat.rb` Homebrew cask, `scripts/build-release.sh` DMG 빌드

외부 의존성: Lemon Squeezy(글로벌 결제·웹훅), Toss Payments(국내 결제), GitHub Releases(DMG 배포), Homebrew(설치 경로).

---

## 2. 에이전트 역할 분담

**Claude Code = 오케스트레이터**
- 사용자와의 대화, 의도 해석, 계획 수립
- 여러 파일을 가로지르는 일관성 있는 수정
- git 상태 확인, 커밋 분리, 커밋 메시지 작성
- Codex가 반환한 결과물 검증·통합
- `.codex/TASK.md` 갱신

**Codex CLI = 실행자**
- 격리된 단일 파일/단일 모듈 작성 및 리팩터
- 긴 보일러플레이트(스키마 SQL, 테스트 케이스, 문서 초안)
- Second opinion / 코드 리뷰 요청
- 결과는 **변경 요약 + 핵심 diff**로 전달 (파일 전체 덤프 금지)

**공통 원칙**
- 같은 파일을 두 에이전트가 동시에 수정하지 않는다. 작업은 순차로만.
- 파일을 바꾸기 전에 `AGENTS.md`와 `.codex/TASK.md`를 먼저 읽는다.
- 작업 중 중요한 결정이 생기면 `.codex/TASK.md`에 기록한다.

---

## 3. 언어 규칙

- **사용자 응답·커밋 메시지·코드 주석**: 한국어
- **식별자·파일명·관용 기술 용어**: 영어 (함수명·변수명·타입명)
- **문서 파일(Markdown)**: 한국어 중심, 코드 블록만 영어
- 이모지는 사용자가 명시적으로 요청할 때만 사용

---

## 4. 코딩 스타일 (전역)

- **불변성**: 객체를 직접 변이시키지 말고 새 객체 생성 (`return { ...user, name }`)
- **파일 크기**: 200~400줄이 표준, 800줄을 넘기면 분리 검토
- **함수 크기**: 50줄 이내
- **에러 핸들링**: 외부 경계(HTTP, 파일, DB)에서는 반드시 try/catch + 의미 있는 메시지
- **입력 검증**: 경계 입력은 zod 스키마로 파싱 (backend는 `validators.js` 패턴 유지)
- **주석**: 기본은 쓰지 않는다. "왜"가 자명하지 않을 때만 한 줄로.
- **console.log / print 디버깅 라인**: 커밋 전에 반드시 제거

---

## 5. 커밋 규칙

- Conventional Commits: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`
- 제목은 간결하게(70자 이내), 본문에는 **why** 중심
- 한국어 허용. 예: `refactor: 완충 기준을 사용자 지정값으로 통일`
- 여러 주제가 섞이면 PR 하나가 커밋 3~5개로 쪼개지는 것을 기본으로 둠
- 자동 서명/AI attribution 라인 추가 금지 (`settings.json`에서 전역으로 꺼둠)
- `git push --force`, `--no-verify`, `reset --hard` 등 파괴적 명령은 사용자 승인 없이 실행 금지

---

## 6. Pro 기능 관련 아키텍처 제약

Pro 기능을 건드리는 변경은 세 곳이 동시에 맞물립니다. 하나라도 빠지면 앱이 반쪽으로 출시됩니다.

1. **Swift 앱**
   - `Licensing/LicenseState.swift`의 `ProFeature` enum에 기능 추가
   - `Licensing/EntitlementStore.swift`에서 entitlement 분기
   - `AppModel` / UI에서 `canCustomizeAnimations` 같은 computed property 게이트
2. **백엔드**
   - 필요한 경우 라이선스·자산 엔드포인트 추가 (`backend/src/app.js`)
   - 스키마 검증을 `validators.js`에 둔다
3. **문서·카피**
   - `Shared/AppLanguage.swift`에 한·영 카피 추가
   - 필요 시 `index.html` Pro 섹션 업데이트

Free 사용자 경로는 절대 깨뜨리지 않는다. 기본값(bundled 애니메이션)은 항상 동작해야 한다.

---

## 7. 주요 명령어

백엔드:

```bash
cd backend
npm run dev     # node --watch, .env 자동 로드
npm start       # 프로덕션 부팅
npm test        # node --test
```

Swift 앱:

```bash
swift build
swift test
scripts/build-release.sh   # DMG 빌드 + Cask 자동 패치
```

랜딩페이지: `index.html` 정적 파일, 별도 빌드 없음.

---

## 8. 현재 진행 중인 이관

**SQLite → MySQL 이관 (Docker Compose)**

- 목표: 백엔드를 Azure Container Apps에 배포하기 위해 파일 기반 SQLite를 제거하고 MySQL로 전환
- 이관 대상 파일: `backend/src/database.js`(617줄), `backend/src/app.js`의 30여 개 호출부, `backend/.env.example`, `backend/package.json`
- 로컬 개발은 `docker-compose.yml`로 `mysql:8` 컨테이너 + 볼륨
- 세부 진행 상황은 `.codex/TASK.md` 참조

---

## 9. 에이전트 호출 프로토콜

Claude가 Codex에 작업을 위임할 때는 다음 구조를 지킵니다.

1. **컨텍스트 지시**: "이 작업 전에 `AGENTS.md`와 `.codex/TASK.md`를 먼저 읽어라"
2. **범위 명시**: 건드려야 할 파일 경로와 건드리면 안 되는 파일 경로
3. **완료 기준**: 무엇이 되면 끝난 것인가 (예: "`npm test` 통과", "부팅 후 /healthz 200")
4. **반환 형식**: 변경 요약 + 핵심 diff. 파일 전체를 그대로 돌려주지 말 것.

Codex가 작업 중 결정이 필요한 지점을 만나면 임의로 진행하지 말고 Claude에게 질문으로 되돌려보낸다.
