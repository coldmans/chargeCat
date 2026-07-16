# AGENTS.md

이 문서는 Claude Code와 Codex CLI가 이 저장소에서 공동으로 작업할 때 따라야 하는 **불변 규칙과 공통 컨텍스트**를 정의합니다. 에이전트가 새 세션을 시작하면 가장 먼저 이 파일을 읽고 작업에 들어갑니다.

프로젝트 루트: `/Users/coldmans/Documents/GitHub/chargeCat`

---

## 1. 프로젝트 개요

ChargeCat은 맥북 사용자가 충전기를 꽂을 때 화면 구석에 작은 고양이 애니메이션을 띄워주는 macOS 메뉴바 앱입니다. 현재 배포 방향은 **무료 배포**입니다. 이벤트별 애니메이션 변경과 다운로드 가능 팩은 모두 무료 기능이며, 결제/라이선스 흐름은 제거되어 있습니다.

구성 요소:

- **macOS 앱 (Swift / SwiftUI)** — `Sources/ChargeCat/`
  - `App/` 앱 상태(`AppModel`), `Battery/` 충전 감지, `Overlay/` 오버레이 표시
  - `Panel/` 제어판 UI, `Animation/` 에셋 로딩·재생, `Shared/BackendConfiguration.swift` 다운로드 catalog 설정
  - `Settings/` UserDefaults 래퍼, `Shared/AppLanguage.swift` 로컬라이제이션
- **백엔드 (Node.js 25 + Express 5)** — `backend/src/`
  - `app.js` 공개 asset catalog/download 엔드포인트, `config.js` 환경 설정, `validators.js` zod 스키마
  - DB, Lemon/Toss 결제, 라이선스 활성화, checkout 페이지는 현재 사용하지 않음
- **랜딩 페이지** — 루트 `index.html` (GitHub Pages)
- **배포 자산** — `ChargeCat.xcodeproj` App Store 타깃, `scripts/build-app-store.sh` App Store 아카이브, `Casks/charge-cat.rb` Homebrew cask, `scripts/build-release.sh` DMG 빌드

외부 의존성: Mac App Store, GitHub Releases(DMG 배포), Homebrew(설치 경로), 선택적 asset catalog 백엔드.

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

## 6. 무료 배포 관련 아키텍처 제약

- 결제, 라이선스 키, Pro paywall을 새로 추가하지 않는다. 필요하면 별도 사용자 확인을 먼저 받는다.
- 이벤트별 애니메이션 변경과 추가 팩 다운로드는 무료 사용자에게 항상 열려 있어야 한다.
- 기본 bundled 애니메이션은 백엔드 연결 없이 항상 동작해야 한다.
- 추가 애니메이션 catalog는 선택 기능이다. `backend-config.json`에 catalog URL이 없으면 앱은 조용히 기본 에셋만 보여준다.
- 백엔드 다운로드 엔드포인트는 라이선스 헤더를 요구하지 않는다.

UI/문서/백엔드 중 하나라도 유료 흐름을 다시 암시하지 않게 같이 정리한다.

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
scripts/build-app-store.sh <version> <build-number>
scripts/build-release.sh   # DMG 빌드 + Cask 자동 패치
```

랜딩페이지: `index.html` 정적 파일, 별도 빌드 없음.

---

## 8. 현재 진행 중인 정리

**무료 배포 전환**

- 결제/라이선스/DB 스택은 제거하고, 앱은 기본 기능과 추가 애니메이션 팩을 무료로 제공한다.
- 백엔드는 선택적 공개 asset catalog/download 서버로만 유지한다.
- 세부 진행 상황은 `.codex/TASK.md` 참조

---

## 9. 에이전트 호출 프로토콜

Claude가 Codex에 작업을 위임할 때는 다음 구조를 지킵니다.

1. **컨텍스트 지시**: "이 작업 전에 `AGENTS.md`와 `.codex/TASK.md`를 먼저 읽어라"
2. **범위 명시**: 건드려야 할 파일 경로와 건드리면 안 되는 파일 경로
3. **완료 기준**: 무엇이 되면 끝난 것인가 (예: "`npm test` 통과", "부팅 후 /healthz 200")
4. **반환 형식**: 변경 요약 + 핵심 diff. 파일 전체를 그대로 돌려주지 말 것.

Codex가 작업 중 결정이 필요한 지점을 만나면 임의로 진행하지 말고 Claude에게 질문으로 되돌려보낸다.
