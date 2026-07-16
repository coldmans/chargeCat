# Charge Cat Asset Catalog

무료로 제공할 추가 애니메이션 팩을 여기에 둡니다.

## Files

- `catalog.json`: `GET /api/assets/catalog`가 반환하는 공개 asset catalog
- `files/`: 백엔드가 그대로 내려주는 GIF/MOV 파일

## Catalog Shape

```json
{
  "assets": [
    {
      "id": "sleepy-cat",
      "title": "Sleepy Cat",
      "mediaType": "video",
      "filename": "sleepy-cat.mov",
      "systemImage": "moon.zzz.fill",
      "soundProfile": "silent",
      "previewHeight": 96,
      "overlayHeight": 240,
      "recommendedEvent": "fullyCharged"
    }
  ]
}
```

## Notes

- `filename`은 `backend/assets/files/` 기준 상대 경로입니다.
- `downloadURL`에 절대 URL을 넣으면 앱은 그 URL을 바로 받습니다.
- `mediaType`은 `gif` 또는 `video`입니다.
- `soundProfile`은 `silent`와 `doorCat`을 지원합니다.
- `recommendedEvent`는 `chargeStarted`와 `fullyCharged`를 지원합니다.
