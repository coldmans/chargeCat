# Charge Cat for Windows

Windows 전용 구현은 `windows/ChargeCat.Windows/` 아래에 들어 있습니다.

현재 구성:

- `.NET 8` + `Windows Forms`
- 시스템 트레이 상주
- 충전 시작 / 완충 감지
- 좌하단 / 우하단 GIF 오버레이
- 설정 창
- 시작프로그램 등록
- 현재 전원 계획 읽기
- macOS 버전과 동일한 `cat-door.gif` 리소스 재사용

빌드 예시:

```powershell
cd windows
./build-release.ps1 -Version 1.0.0
```

개발 실행 예시:

```powershell
dotnet run --project .\ChargeCat.Windows\ChargeCat.Windows.csproj
```

주의:

- 이 저장소에서는 macOS 환경에서 작성되어 로컬 Windows 빌드는 검증하지 못했습니다.
- 리소스 GIF는 `ChargeCat.Windows/Assets/cat-door.gif`를 사용합니다.
- macOS의 `Sound` 기능은 Windows 프로젝트에 아직 연결하지 않았습니다.
