# Charge Cat Asset Catalog

Add downloadable Pro animation packs here.

## Files

- `catalog.json`: public asset catalog returned by `GET /api/assets/catalog`
- `files/`: actual downloadable GIF/MOV assets that the backend serves after Pro license verification

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

- `filename` is resolved against `backend/assets/files/`
- `downloadURL` can be used instead of `filename` if the asset is hosted elsewhere, and the backend will proxy it after Pro validation
- `mediaType` must be `gif` or `video`
- `soundProfile` supports `silent` and `doorCat`
- `recommendedEvent` supports `chargeStarted` and `fullyCharged`
