# MonCook 작업 상태 — Phase 0.8 UI Polish

기록일: 2026-10-06 (한국 시간). 브랜치: `feature/moncook-foundation`. [Draft PR #1](https://github.com/wnfpvm13/Gameproject1/pull/1). 이번 지침: [UI Polish](docs/NEXT_CODEX_INSTRUCTION_Phase_0_8_UI_Polish.md). 이전 기능 구현·검증 보고는 [보관본](docs/implementation-reports/Phase_0_8_Foundation.md)에 있습니다.

## 1. 구현 내용

사용자는 기존 Phase 0.8 파티 기능의 Studio 정상 동작을 확인했습니다. 이번 작업은 해당 기능을 그대로 두고 UI Presentation만 다듬었습니다. CODEX_START_HERE·MASTER_GDD·PARTY_EXPEDITION·UI_UX·CODEX_RULES·기존 작업 상태와 관련 데이터/아키텍처를 먼저 읽었습니다. 새 게임 시스템 구현으로 넘어가지 않고 UI Polish에서 종료합니다.

Finder를 **68px 카드**로 바꾸고 활동/목표는 첫 줄, 호스트·인원·모집 상태는 둘째 줄에 배치했습니다. 상태 오른쪽의 **44×44px 참가 버튼**은 같은 행 중심에 정렬합니다. 기존 전체 너비의 큰 하단 버튼을 제거했습니다. 인원수는 고정 영역에 보존하고 긴 이름/목표는 줄임표를 사용합니다. 가입 가능 여부와 JoinPublic payload는 기존 그대로입니다.

색상은 PartyUIStyle의 반투명 웜브라운/웜그레이와 밝은 텍스트로 분리했습니다. 패널 RGB는 61/53/48, BackgroundTransparency는 0.16이며 완전 검정은 사용하지 않습니다. 카드·얼굴·배지·텍스트·스크롤바·버튼 색도 같은 Theme에서 제공합니다. 따뜻한 브라운/골드 포인트를 유지합니다.

버튼 helper가 Normal / Hover / Pressed / Disabled를 재사용합니다. Hover는 밝게, Pressed는 진하게, Disabled는 채도를 낮추고 투명하게 표시합니다. 전환은 0.08초입니다. 마우스·Touch·Gamepad 선택과 누름, 밖에서 놓기·두 번째 Touch·창 포커스 이탈·메뉴 열기·컨트롤 파괴 시 입력/Tween 정리를 처리하며 실제 Activated 기능은 기존 HUD가 담당합니다.

Collapsed는 최대 4명의 **세로 얼굴 스택**입니다. 모바일 기본 폭은 88px, 넓은 화면은 136px로 짧은 이름도 표시합니다. 작은 왕관과 준비 아이콘을 유지하고 44px 펼치기 버튼을 둡니다. 공간이 부족하면 멤버 영역을 세로 스크롤합니다. Expanded는 최대 폭 300px·높이 420px/화면 70% 범위에서 목표·공개 여부·멤버 얼굴/리더·준비·초대·탈퇴·Finder를 표시합니다. 좁은 열에서는 버튼을 44px 높이의 세로 행으로 배치하고 문구를 줄바꿈합니다.

상단 **전용 드래그 손잡이**는 PC 마우스와 Touch를 받으며 펼치기/참가/Ready 버튼과 영역을 분리했습니다. 위치는 safe-area 좌표의 normalized X/Y 선호점으로 분리해 후속 저장을 연결할 수 있습니다. 현재 클라이언트 세션 안에서만 유지하고 영구 저장은 하지 않습니다. 화면 크기 변경·회전·확대/축소 때 유효 영역과 측정 가능한 CoreUI 사각형 안에서 위치를 보정합니다.

공개 Chat 창/입력창의 실제 사각형과 TopBar·Safe Area를 회피하고 Roblox Menu가 열리면 파티 HUD만 숨깁니다. 넓은 화면의 PlayerList는 추정 사각형을 예약합니다. 좁은 화면에는 compact 대체 정책을 사용합니다. 실제 크기가 공개되지 않는 PlayerList와 물리적으로 화면 전체를 덮는 Chat은 완전한 비겹침을 보장할 수 없으므로 아래 수동 판정이 남습니다.

ReadyCheck의 `✓ 함께 이동 / … 응답 중 / — 이번엔 남음` 아이콘·텍스트를 밝게 표시하고 `3 / 4명 이동 준비`처럼 요약합니다. 기존 Foundation Debug UI와 Studio AND ShowFoundationDebugUI 게이트 및 기본 false는 그대로입니다.

## 2. 변경 파일

- `src/client/Controllers/PartyHUD.luau`: 카드·반투명 테마·세로 스택·멤버 행·드래그·반응형 표시 연결
- `src/client/Controllers/PartyButtonStyle.luau`: 재사용 시각 상태와 Roblox 입력/Tween 정리
- `src/shared/Config/PartyUIStyle.luau`: 순수 Theme·상태별 스타일 데이터
- `src/shared/Utilities/PartyHUDGeometry.luau`: 세로 치수·선호 위치/Clamp·resize·CoreUI 회피·카드/버튼 행 계산
- `tests/PartyHUDGeometry.spec.luau`, `PartyUIStyle.spec.luau`: UI 회귀 검사 28개 그룹
- `docs/NEXT_CODEX_INSTRUCTION_Phase_0_8_UI_Polish.md`: 이번 사용자 지시 기록
- `docs/implementation-reports/Phase_0_8_Foundation.md`: 이전 작업 상태 원문 보관
- `README.md`, `FOUNDATION_QA.md`, 이 파일: 최신 실행·수동 판정·6항목 보고

## 3. 테스트 결과

- 기준 실행에서 기존 **141개 그룹**이 통과했습니다. 기존 테스트 파일을 수정하지 않았으며 최종에도 모두 통과했습니다.
- 공식 Luau 0.741: **43개 Luau 파일 문법 컴파일**, 순수 모듈 strict 분석, **총 169개 그룹 통과**. 기존 141 + Geometry 19 + Style 9입니다.
- Geometry: 세로 최대4·empty·작은 portrait viewport, 화면 밖 드래그·normalized 값·resize/clamp, Chat/TopBar·PlayerList 예약·zero startup·narrow expansion/automatic compact, Finder 상태/버튼 중심·최소 터치·고정 인원, 좁은 버튼 세로 행을 검증했습니다.
- Style: 네 상태의 우선순위·명도·Disabled 채도/투명도·반투명 표면·비검정 테마·동결·fallback·작은 전환값을 검증했습니다. 실제 Hover/Press 입력 검증과는 구분합니다.
- 기존 서버·테스트·Definitions/Registry·Foundation 연결·Debug UI·PartyPresentation/기존 Layout **33개 파일이 이전 커밋과 바이트 동일**함을 확인했습니다. 서버와 저장/경제 계약은 수정하지 않았습니다.
- Rojo 7.7.1로 `.rbxlx`를 빌드하고 포함한 **29개 스크립트/모듈의 경로·타입·소스 일치**를 확인했습니다. Roblox 엔진 실행 결과가 아닙니다.
- git diff 공백 검사 통과. 공유 사본·새 전체 소스 ZIP·Studio 파일은 저장소/빌드 원본과 바이트 단위로 비교했습니다. PC 설치 도구는 이번에 변경하지 않았습니다.

## 4. 실제 Studio 미검증 항목

이번 환경에는 Roblox Studio 연결이 없어 **새 UI의 실제 수동 QA를 실행하지 못했습니다**. 사용자에게서 받은 이전 파티 기능의 정상 동작 판정과 이번 UI Polish 검증을 구분합니다.

필수 수동 항목은 Finder 참가 버튼 위치·긴 이름/목표·비활성 표시, Hover/Pressed 복구, 반투명 배경, PC/Touch 드래그와 회전, 축소 세로 얼굴/왕관, 모바일 세로·가로, Chat/PlayerList/TopBar/Menu/Safe Area 겹침, Gamepad 포커스와 기존 Debug 독립성입니다. 절차는 [FOUNDATION_QA.md](FOUNDATION_QA.md)에 있습니다.

PlayerList 실제 bounds는 공개 API가 없어 넓은 화면 예약·좁은 화면 fallback은 실제 화면 판정이 필요합니다. 전체 화면 Chat처럼 빈 공간 자체가 없는 경우 `ChatSpaceFallback`으로 안전 영역 안에 유지하며 비겹침 판정은 남습니다. UI 코드의 Roblox 타입/이벤트 실행도 문법 검사만으로 통과했다고 판정하지 않습니다.

Windows PC 설치는 이 클라우드에서 직접 실행하지 못했습니다. 새 ZIP의 `Install-LocalProject.ps1`로 `C:\smallsize\wak\MonCook`과 `C:\smallsize\wak\MonCook_LocalRepository\MonCook`에 백업 복사할 수 있습니다. Published/API·Expedition 실제 이동·콘텐츠는 이전 보고의 미검증/미구현 범위를 유지합니다.

## 5. TODO

- 최신 `MonCook_Phase_0_8_UI_Polish.rbxlx`로 위 Studio 수동 항목을 판정하고 화면 크기·입력 장치·Output 근거를 기록합니다.
- 실제 PlayerList variants·모바일 Chat 표시 상태에 맞춰 UI 예약 치수를 조정할 필요가 있는지 확인합니다.
- 후속 요청이 있으면 normalized PositionPreference의 저장을 연결할 수 있습니다. 이번에는 세션 로컬 상태만 사용합니다.
- 현재 작업은 **Phase 0.8 UI Polish 완료 상태에서 종료**합니다. 전투·드롭·경제·원정/식당 서버 확장·Quick Match는 이번에 진행하지 않습니다.

## 6. 다른 브랜치 영향

모든 변경은 `MonCook/` 아래의 UI·Presentation·새 UI 검사·문서입니다. 기존 `feature/moncook-foundation`과 Draft PR #1을 갱신하며 main 병합·Roblox 게시를 하지 않습니다. 다른 게임 파일은 변경하지 않았습니다.

PartyService·Public/Private·Finder 서버·ReadyCheck·ExpeditionSession·FakeTeleport·Restaurant Session·DataService와 경제/저장/migration은 바이트 그대로입니다. Remote action·payload·snapshot 계약은 바뀌지 않습니다. Debug UI/게이트도 그대로입니다.

후속 UI 브랜치는 PartyUIStyle·PartyButtonStyle·PartyHUDGeometry를 재사용할 수 있습니다. 새 Theme는 서버 Config Registry family를 바꾸지 않는 표시 전용 모듈입니다. 기존 PartyHUDLayout과 141개 테스트를 보존했습니다. 공유본과 PC ZIP을 갱신했고 새 게임 시스템으로 넘어가지 않습니다.
