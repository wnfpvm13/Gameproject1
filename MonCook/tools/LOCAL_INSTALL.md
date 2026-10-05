# Windows 컴퓨터에 문서 저장

배포 ZIP 전체를 임시 폴더에 풀고, `docs`와 `tools` 폴더가 보이는 위치에서 PowerShell을 열어 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Install-LocalDocs.ps1
```

다음 두 위치에 문서 전체를 복사하며, 없는 폴더는 만듭니다.

- 소스 프로젝트: `C:\smallsize\wak\MonCook\docs`
- 개인 저장소: `C:\smallsize\wak\MonCook_LocalRepository\MonCook\docs`

각 위치의 `LastRecipe_Codex_Design\CODEX_START_HERE.md`부터 읽습니다. 통합 문서 `The_Last_Recipe_ALL_IN_ONE_CODEX_SPEC.md`도 함께 저장됩니다.

기존 파일과 내용이 같으면 건너뜁니다. 내용이 다른 파일은 `docs`의 상위 폴더 아래 `.MonCook-docs-backups\날짜-실행ID`에 먼저 백업한 뒤 교체합니다. 배포본에 없는 기존 파일은 삭제하지 않습니다. 이 스크립트는 폴더와 문서만 준비하며 Git 저장소 초기화, 원격 연결, 업로드를 수행하지 않습니다.

복사할 위치만 미리 확인하려면 명령 끝에 `-WhatIf`를 붙입니다. 경로를 바꾸려면 다음과 같이 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Install-LocalDocs.ps1 -SourceProjectPath 'D:\Games\MonCook' -PersonalRepositoryPath 'D:\MyRepositories'
```

이 예시는 `D:\Games\MonCook\docs`와 `D:\MyRepositories\MonCook\docs`에 복사합니다. ZIP을 푼 폴더 안으로 설치하거나, 두 설치 위치가 서로 포함되도록 지정하면 오류로 중단합니다. 폴더 및 파일 연결(심볼릭 링크·정션)도 지원하지 않습니다.

이 안내와 스크립트를 제공한 것만으로 사용자 컴퓨터에 복사가 완료되지는 않습니다. 위 명령을 사용자 컴퓨터에서 실행해야 합니다.
