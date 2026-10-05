# MonCook 작업 상태

## 1. 구현 내용

첨부 `LastRecipe_Codex_Design_v1.zip`의 문서 21개를 `MonCook/docs`에 원본 그대로 보관했습니다. `CODEX_START_HERE.md`부터 읽고 분리 문서 전체와 관련 데이터·파티·식당 계약을 확인했습니다.

Phase 0 Foundation 0.1–0.7의 코드가 있습니다. Config/PlayerData 계약에 이어 DataService의 load/save/update와 원자적 서버 잠금, 최대 4인 파티·리더 이전·JOIN/STAY 동의, Restaurant SessionId·pantry escrow·상태 전이·중복 정산 영수증을 구현했습니다.

Studio 메모리 저장소·FakeTeleport와 실제 Roblox API 어댑터를 연결했습니다. 이동 전 프로필 잠금을 해제하고 목적지에서 다시 얻으며, 전송 실패·늦은 실패 콜백·동시 helper 복귀·저장 중 heartbeat·퇴장 복구를 처리합니다. 서버가 경제 데이터와 세션을 검증하며 TeleportData에는 SessionId·목적지·이동 시도 ID만 넣습니다.

PC/Touch/Gamepad용 파티·입장·복귀 UI와 테스트용 바닥/Spawn을 추가했습니다. 현재 정산은 Gold/Renown 0, 맡긴 식재료 전량 반환 골격입니다. Phase 0의 Studio/Published Acceptance는 아직 통과 판정하지 않았습니다.

전체 프로젝트를 소스 폴더와 개인 저장소 폴더에 안전하게 복사하는 PowerShell 도구도 포함했습니다. 동일 파일은 건너뛰고 변경된 파일을 백업하며 기존 추가 파일은 보존합니다.

## 2. 변경 파일

- `docs/`: 원본 설계 문서 21개
- `src/shared/`: Config Registry·PlayerData 타입·기본값·migration
- `src/server/Services/`: DataService·PartyService·SessionService·FoundationCoordinator·TeleportServiceWrapper·FakeTeleport
- `src/server/Adapters/`, `ServerConfig.luau`, `Foundation.server.luau`: Roblox/Studio 어댑터·설정·서버 시작 및 요청/접속/실패 처리
- `src/client/Controllers/Foundation.client.luau`: 파티·입장·복귀 UI
- `default.project.json`: Rojo 구조·StreamingEnabled·테스트 공간
- `tests/`, `tools/run_foundation_tests.py`: 공통 계약·저장·파티·세션·통합 실패 테스트
- `tools/Install-LocalProject.ps1`, `LOCAL_PROJECT_INSTALL.md`: 전체 프로젝트 PC 보관
- `tools/Install-LocalDocs.ps1`, `LOCAL_INSTALL.md`: 문서 전용 PC 보관
- `README.md`, `FOUNDATION_QA.md`, `.gitignore`, 이 파일: 실행 안내·QA·작업 상태

## 3. 테스트 결과

- 문서 21개가 첨부 ZIP 원본과 바이트 단위로 일치합니다.
- 공식 Luau 0.741로 소스·테스트 Luau 파일 23개의 문법 컴파일을 통과했습니다.
- require 경로만 CLI용으로 변환한 임시 사본에서 순수 모듈과 테스트의 strict 타입 분석을 통과했습니다. Roblox 어댑터·시작 코드·클라이언트는 문법 컴파일 대상이며 Roblox 타입 분석 대상은 아닙니다.
- 66개 그룹 통과: 공통 계약 10, DataService 14, 파티/텔레포트 16, 세션 14, Coordinator 통합 12.
- 만료·중복 잠금, UpdateAsync 재시도 시 변이 1회, 저장 실패 시 캐시 보존, 동시 저장/heartbeat, 퇴장 후 갱신 중단, escrow 실패 원복, 반복 정산, 동의 변경 경합, 오래된 이동 실패 무시, 독립 세션·helper 동시 복귀를 검증했습니다.
- Rojo 7.7.1로 Studio에서 열 수 있는 `.rbxlx`를 빌드했습니다. 이는 Roblox 엔진 실행 결과가 아닙니다.
- PowerShell 7.6.6의 Linux 실행에서 전체 프로젝트 설치 도구의 12개 검증을 통과했습니다. WhatIf 무변경, 공백 경로의 양쪽 복사·파일 해시 일치, 동일 재실행 무변경, 변경 파일 백업, 추가 파일·기존 Git 정보 보존, 빌드/ZIP 제외, 경로 겹침·링크·불완전 번들 거부를 확인했습니다. 문서 전용 도구도 복사/백업/재실행 검증을 통과했습니다.

## 4. 실패·미검증 항목

현재 로직 검사에서 실패한 항목은 없습니다. Roblox Studio 연결이 없어 실제 서버/클라이언트·모바일/Gamepad UI·Published Reserved Restaurant·실제 API 저장·재접속/텔레포트 복구는 미검증입니다. 확인 절차는 `FOUNDATION_QA.md`에 있습니다.

Windows PowerShell 5.1과 사용자 PC에서의 실제 복사는 미검증입니다. 이 클라우드 채팅은 `C:` 드라이브에 직접 접근할 수 없습니다. 제공된 전체 소스 ZIP을 PC의 임시 폴더에 풀고 설치 스크립트를 실행해야 로컬 복사가 완료됩니다.

## 5. TODO

- 실제 World/Restaurant Place ID 설정과 Studio·Published Phase 0 Acceptance. 이를 통과한 뒤 Phase 1의 Hornboar 사냥 공급망으로 진행합니다.
- Published 양수 재고 fixture, API 부하·잠금 만료 대기·텔레포트 실패 QA.
- 조리 소비·판매 장부가 생긴 후 Gold/Renown 정산 구현. 정산 영수증 보존/보관 정책은 운영 데이터량에 맞춰 후속 설계합니다.
- Phase 6의 실제 2–4인 Restaurant QA, 호스트 재접속 유예, helper 보상 확장.
- `EquippedWeaponId`의 Config ID/장비 인스턴스 ID 계약 확정. 기타 미정 컬렉션 구조와 테스트 밸런스는 `TODO_SCHEMA`/`TODO_BALANCE`로 표시했습니다.

## 6. 다른 브랜치 영향

모든 저장소 변경은 `MonCook/` 아래입니다. 다른 게임 파일이나 저장소 루트 API는 수정하지 않았습니다. 작업 브랜치는 `feature/moncook-foundation`이며 main에 직접 수정하지 않습니다.

후속 브랜치의 공통 계약은 `Registry.validate/get/Definitions`, `PlayerDataDefaults.new`, `PlayerDataMigration.migrate`, `DataService.Load/Get/Update/Save/Release`, `PartyService`, `SessionService`입니다. 서비스에는 저장소·시계·ID 생성기·전송을 주입할 수 있습니다. Roblox 런타임 어댑터는 서버에만 둡니다.

main 병합·Roblox 게시·사용자 PC 설치는 수행하지 않았습니다. 공유 보관본에는 소스 ZIP과 Studio 확인용 파일을 제공합니다.
