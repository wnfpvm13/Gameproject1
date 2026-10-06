# Windows 컴퓨터에 MonCook 프로젝트 저장

소스 ZIP 전체를 **설치 대상과 별개의 임시 폴더**에 풉니다. `MonCook` 폴더가 보이는 ZIP 해제 위치에서 PowerShell을 열어 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MonCook\tools\Install-LocalProject.ps1
```

프로젝트 소스, 문서, 테스트와 도구를 다음 두 위치에 복사하며, 없는 폴더는 만듭니다.

- 소스 프로젝트: `C:\smallsize\wak\MonCook`
- 개인 저장소: `C:\smallsize\wak\MonCook_LocalRepository\MonCook`

같은 파일은 건너뜁니다. 내용이 다른 기존 파일은 각 프로젝트 폴더의 `.MonCook-project-backups\날짜-실행ID`에 먼저 백업한 뒤 교체합니다. 배포본에 없는 기존 파일은 삭제하지 않습니다.

`.git`, 빌드 폴더(`build`, `builds`, `dist`, `out`, `artifacts`, `bin`, `obj`), Python 캐시 폴더, `.MonCook-*` 백업 폴더와 ZIP 파일은 복사하지 않습니다. Git 저장소 초기화, 원격 연결, 업로드는 수행하지 않습니다. 경로가 서로 겹치거나 복사 대상에 심볼릭 링크·정션이 있으면 중단합니다.

저장 위치를 미리 확인하려면 위 명령 끝에 `-WhatIf`를 붙입니다. 위치를 변경하려면 다음처럼 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\MonCook\tools\Install-LocalProject.ps1 -SourceProjectPath 'D:\Games\MonCook' -PersonalRepositoryPath 'D:\MyRepositories'
```

이 예시는 `D:\Games\MonCook`과 `D:\MyRepositories\MonCook`에 저장합니다. 저장 후 `README.md`의 프로젝트 실행 안내와 `docs\LastRecipe_Codex_Design\CODEX_START_HERE.md`를 읽습니다. 문서만 저장하려면 기존 `Install-LocalDocs.ps1` 및 `LOCAL_INSTALL.md`를 사용합니다.

이 안내와 스크립트 제공만으로 사용자 컴퓨터에 복사가 완료되지는 않습니다. 위 명령을 사용자 컴퓨터에서 실행해야 합니다.
