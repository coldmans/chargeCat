# Charge Cat Backend

Charge Cat은 현재 무료 배포 모드입니다. 이 백엔드는 결제나 라이선스를 처리하지 않고, 다운로드 가능한 애니메이션 팩 catalog와 파일만 공개로 제공합니다.

## 제공 엔드포인트

- `GET /healthz`
- `GET /api/assets/catalog`
- `GET /api/assets/download/:assetId`

## 로컬 실행

```bash
npm install
npm run dev
```

환경 변수는 `.env.example`을 기준으로 설정합니다. 파일 기반 DB나 MySQL은 필요하지 않습니다.

## 애니메이션 팩

- `backend/assets/catalog.json`: 앱이 읽는 공개 catalog
- `backend/assets/files/`: 백엔드가 직접 제공하는 GIF/MOV 파일

`catalog.json`의 `filename`은 `backend/assets/files/` 기준 상대 경로입니다. 외부 파일을 직접 쓰고 싶으면 `downloadURL`에 절대 URL을 넣을 수 있습니다.
