# MonCook 작업 상태 — Design Lock 1.1 / Phase 0.8

기록일: 2026-10-06. 작업 브랜치: `feature/moncook-foundation`. [Draft PR #1](https://github.com/wnfpvm13/Gameproject1/pull/1).

## 1. 구현 내용

첨부 설계 1.1로 통합 기준 문서와 해당 분리 문서를 갱신했습니다. 새 `PARTY_EXPEDITION.md`와 Phase 0.8 실행 지침을 추가하고 변경 전 통합본·분리 문서·목록 11개는 `docs/archive/design-lock-1.0/`에 보관했습니다. `CODEX_START_HERE.md`부터 필수 설계 문서를 읽고 이번 범위를 Party UX & Expedition Foundation으로 제한했습니다.

기존 DataService 잠금·저장·migration, Restaurant SessionId·escrow·0보상 반환·중복 정산 방지와 이동 골격을 유지했습니다. 실행 지침의 **기존 Foundation Studio QA 통과는 제공받은 전제**이며 이번 환경에서 재실행한 결과가 아닙니다.

실제 플레이용 파티 HUD에 얼굴·짧은 이름·왕관·접기/펼치기, 활동/목표, 공개/비공개, 준비 요약, 초대·탈퇴·Finder를 연결했습니다. Finder는 현재 World/Hearthcross 서버의 Public 파티만 보여주며 카드 버튼으로 가입합니다. Private는 초대 수락이 필요합니다. 초대는 서버가 대상·권한·TTL·정원을 검사하며 목표/공개 여부 변경 시 이전 동의 확인·초대를 무효화합니다. 기본 Release UI에는 Party ID 입력이 없습니다. 기존 큰 Debug UI는 별도 모듈로 보존하고 Studio AND `Testing.ShowFoundationDebugUI == true`에서만 표시합니다. 기본값은 false입니다.

JOIN/STAY 내부 계약을 재사용해 `✓ 함께 이동`, `… 응답 중`, `— 이번엔 남음`, `3/4명 이동 준비`를 표시합니다. 버튼은 Activated·선택 가능한 컨트롤을 사용하며 안전 영역·공개 채팅 bounds·PlayerList 예약 영역·작은 화면 스크롤을 처리합니다. PlayerList 실제 bounds는 공개 API가 없어 화면 검증이 남습니다.

ExpeditionSession에 Preparing → Teleporting → Active → Result → Returning → Closed 상태, 호스트·파티·Region/Target·선택 멤버·결과 ActionId·영수증을 추가했습니다. Restaurant과 같은 예약/전송 래퍼를 사용하며 Fake 이동 전후 프로필 잠금을 해제·재획득합니다. 결과는 호스트가 Repeat / HostRestaurant / Hearthcross를 선택합니다. Repeat와 HostRestaurant은 World로 돌아와 새 JOIN/STAY 동의 확인을 생성하고 이후 함께 이동한 멤버만 출발합니다. 사냥·전투·드롭·보상을 구현하거나 경제 데이터를 수정하지 않습니다.

Published Expedition은 상태를 바꾸기 전에 서버에서 차단합니다. 지역별 Place 설정과 전송 API만 후속 연결용으로 마련했습니다. Quick Match는 Enabled Config와 `Available = false / NotAvailable` 인터페이스·TODO만 있으며 MemoryStoreQueue 구현은 없습니다.

호스트 이탈 후 STAY 멤버가 World에서 활동 잠금에 남는 문제를 복구했습니다. 오래된 원정 작업의 실패 정리가 새 Active 세션·동의 확인·초대·잠금 소유권을 덮어쓰지 않도록 작업/파티 세대와 현재 소유권을 검사합니다. Published Restaurant HUD는 검증된 세션 멤버의 표시용 파티를 제공하며 서버 권한은 기존 세션 검증을 사용합니다.

## 2. 변경 파일

- `docs/The_Last_Recipe_ALL_IN_ONE_CODEX_SPEC.md`, `NEXT_CODEX_INSTRUCTION_Phase_0_8.md`: 첨부 원문
- `docs/LastRecipe_Codex_Design/`: 설계 1.1 변경 섹션·새 PARTY_EXPEDITION·README·manifest
- `docs/archive/design-lock-1.0/`: 변경 전 원본 11개
- `src/client/Controllers/`: Foundation 네트워크 연결, PartyHUD, FoundationDebugUI
- `src/shared/Utilities/`: PartyPresentation 및 HUD 레이아웃 로직
- `src/shared/Config/Definitions.luau`, `Registry.luau`: PartyTarget·Region 활동/이동 계약·Debug gating·Matchmaking hook
- `src/shared/Types/ExpeditionSession.luau`: 세션·상태·결과 계약
- `src/server/Services/PartyService.luau`, `PartyActivityService.luau`: Public/Private·초대·준비 상태·이탈 후 복구
- `src/server/Services/ExpeditionService.luau`, `ExpeditionCoordinator.luau`, `MatchmakingService.luau`: 원정 수명주기·Fake 이동/복구·매칭 인터페이스
- `src/server/Services/TeleportServiceWrapper.luau`, `ServerConfig.luau`, `Foundation.server.luau`: 지역별 전송·설정·서버 요청/스냅샷 연결
- `tests/`: 기존 Foundation 확장, PartyUX·표시·레이아웃·활동 복구·원정·원정 Coordinator 회귀 테스트
- `README.md`, `FOUNDATION_QA.md`, 이 파일: 실행·검증·인계 안내

기존 PlayerDataDefaults/Migration·DataService·SessionService·FoundationCoordinator와 PC 설치 도구는 수정하지 않았습니다.

## 3. 테스트 결과

- 두 첨부 원문은 저장소 사본과 바이트 단위로 일치합니다. 설계 SHA256: `9469fac5a7701388c392f9bede172f0d0c9778e02cf5f55039ea43dc5ce14003`, 실행 지침 SHA256: `d3ccff87fba5569b8c958639527c68a5e15b02ebe452bb080952194560892066`.
- 분리 설계 19개 섹션이 새 통합본과 일치합니다. 변경 전 보관본 11개와 변경하지 않은 분리 문서 10개는 이전 커밋 원본과 바이트 단위로 일치합니다.
- 공식 Luau 0.741로 소스·테스트 문법 컴파일, CLI용 require만 변환한 임시 사본의 순수 모듈 strict 타입 분석 및 회귀 테스트를 통과했습니다. 최종 그룹 수는 아래 검증 기록에 기재합니다. Roblox 시작 코드·API 어댑터·UI는 문법 검사 대상이며 Roblox 타입/엔진 실행 검증 대상은 아닙니다.
- 기존 66개 그룹을 유지하고 Public join·Private hidden·정원·공개 여부/목표 변경·초대·준비 표시·Debug gating, 원정 수명주기·중복/오래된 작업·Fake 전송·결과 실패 재시도·호스트 이탈·새 작업 보호를 추가 검증했습니다.
- 작은 화면에서 20인 PlayerList 추정 영역 때문에 HUD가 사라지는 회귀를 순수 레이아웃 계산으로 검증했습니다. 좁은 화면에서 추정 영역이 공간을 모두 차지하면 공개 topbar/chat bounds를 피하는 compact 배치를 사용합니다. 실제 PlayerList overlay와의 겹침은 미검증입니다. 실제 CoreUI 화면 검증과는 구분합니다.
- Rojo 7.7.1의 `.rbxlx` 빌드와 생성 파일의 26개 스크립트/모듈 배치·타입·소스 일치를 확인했습니다. 이는 Studio 엔진 실행 결과가 아닙니다.
- PowerShell 7.6.6 Linux에서 PC 설치 도구의 12개 검증을 통과했습니다. WhatIf, 두 경로의 전체 파일 해시, 동일 재실행, 변경 파일 백업, 추가 파일·Git 정보 보존, ZIP/빌드 제외, 경로 겹침·링크·불완전 번들 거부를 확인했습니다.
- 공유 소스 사본·전체 소스 ZIP은 저장소 파일과 바이트 단위로 비교했습니다. ZIP에 Studio 확인용 `.rbxlx`와 Windows 실행 안내도 포함합니다.

최종 로직 검증: **Luau 38개 파일 문법, 순수 모듈 strict 분석, 141개 그룹 통과**. Coordinator 12, DataService 14, Expedition 14, ExpeditionCoordinator 14, Foundation 12, PartyActivity 12, PartyHUDLayout 8, PartyPresentation 6, PartyTeleport 16, PartyUX 19, SessionService 14.

## 4. 미검증 항목

로직 검사에서 알려진 실패는 없습니다. Roblox Studio 연결이 없어 **Phase 0.8 실제 2–4인 실행, 20인/모바일 세로·가로 CoreUI 겹침과 스크롤, Touch/Gamepad 포커스, 실제 Restaurant 왕복·API 저장·재접속**은 미검증입니다. 확인 순서는 `FOUNDATION_QA.md`에 있습니다.

Published Expedition의 세션 저장·목적지 도착 import·cross-server 복구와 실제 사냥 콘텐츠는 미구현입니다. Published 시작을 차단했으므로 전송 래퍼가 있다는 이유로 출시 가능한 원정으로 판정하지 않습니다. 기존 Published Restaurant도 실제 Place ID가 0이므로 설정·실행 QA가 필요합니다.

Windows PowerShell 5.1과 사용자 PC의 실제 설치는 미검증입니다. 클라우드 환경은 `C:` 드라이브에 직접 접근하지 못합니다. 공유 `MonCook_Phase_0_8_Source.zip`을 PC 임시 폴더에 풀어 `MonCook/tools/Install-LocalProject.ps1`을 실행하면 `C:\smallsize\wak\MonCook`과 `C:\smallsize\wak\MonCook_LocalRepository\MonCook`에 복사합니다. 변경 파일은 백업하고 기존 추가 파일은 보존합니다.

## 5. TODO

- Phase 0.8 Studio 파티 UX·Expedition·모바일/Gamepad QA와 작은 화면 CoreUI 판정 기록.
- World/Restaurant 실제 Place ID와 테스트 Experience·양수 escrow fixture를 설정하고 Published 기존 저장·왕복·실패 복구 검증.
- Published Expedition 지역 Place·공유 세션 저장·도착 검증·잠금 인계·실패/재접속 복구 설계 및 구현. `ExpeditionPlaceIds`만 설정해서 차단을 해제하면 안 됩니다.
- 실제 Hornboar 공급망·전투·드롭·개인 기여도/보상·원정 콘텐츠는 후속 Phase. TwinOgre 목표는 계약용이며 몬스터 구현은 없습니다.
- Quick Match V1.5의 cross-server 정책·큐·중복 매칭/취소 계약은 후속 범위.
- 실제 조리·판매 장부 이후 Gold/Renown 정산, 호스트 재접속 유예·helper 보상과 영수증 보관 정책 확장.
- Config의 `TODO_SETUP`, `TODO_BALANCE`, `TODO_SCHEMA` 검토. PlayerData SchemaVersion 변경은 이번에 필요하지 않습니다.

## 6. 다른 브랜치 영향

모든 변경은 `MonCook/` 아래입니다. 다른 게임과 저장소 루트 파일은 수정하지 않았습니다. 기존 `feature/moncook-foundation`과 Draft PR #1을 갱신하며 main 병합·Roblox 게시는 수행하지 않습니다.

기존 PartyService 메서드는 유지합니다. `Create(userId, settings?)`, Visibility/Activity/TargetId/Status/ReadyStates·Public Finder·Invite API가 추가되었습니다. ReadyStates는 내부 숫자 키이며 Remote snapshot에서는 문자열 키로 변환합니다. 서버가 Config의 Activity/Target을 검증하므로 후속 Config에는 PartyTarget family와 Region.ActivityMode/TravelMode 참조 계약이 필요합니다.

ExpeditionService와 ExpeditionCoordinator는 새 런타임 계약입니다. Party·Restaurant Session·Expedition의 ID와 상태를 혼용하지 않습니다. 전송 래퍼에는 선택적 ExpeditionPlaceIds·ReserveExpedition·ToExpedition이 추가되었고 기존 Restaurant/World API는 유지했습니다. Matchmaking은 사용 불가 hook입니다. PlayerData 저장 형식·migration·정산 경제 계약은 바뀌지 않습니다.

후속 브랜치는 새 목표/이동 연결 시 현재 제안·선택 멤버·서버 권한과 작업 소유권 검사를 보존해야 합니다. 공유 보관본과 PC 설치용 ZIP을 함께 제공합니다. 실제 사용자 PC 복사는 아직 실행하지 못했습니다.
