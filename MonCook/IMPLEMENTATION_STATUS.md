# MonCook 작업 상태 — Phase 0.8 Final Drag Clamp

기록일: 2026-10-06 (한국 시간). 브랜치: `feature/moncook-foundation`. [Draft PR #1](https://github.com/wnfpvm13/Gameproject1/pull/1). [이번 지시](docs/FINAL_PHASE_0_8_Party_HUD_Drag_Clamp.md). [이전 UI Polish 보고](docs/implementation-reports/Phase_0_8_UI_Polish.md).

## 1. 구현 내용

사용자는 기존 Party HUD의 기능·크기·색상·Finder·ReadyCheck·드래그가 정상이라고 확인했습니다. 이번 수정은 자동 배치와 수동 위치 제한만 분리합니다. 다른 UI와 게임 시스템은 유지하며 Phase 0.8에서 종료합니다.

기존 `placement()`와 자동 `measure()`는 그대로입니다. 초기 표시와 화면 크기/필수 Safe Area 변경에는 Chat·PlayerList·TopBar 회피와 responsive 측정을 유지합니다.

새 `dragPlacement()`는 Chat/PlayerList obstacle 검색을 하지 않고 필수 viewport/safe-area 경계만 clamp합니다. 사용자가 Chat이나 PlayerList 위에도 HUD를 놓을 수 있으며, 전체 패널·손잡이·펼치기 버튼이 유효 영역 안에 남도록 제한합니다. 현재 크기 측정은 기존 로직을 사용합니다.

HUD는 첫 드래그 이동에서 수동 위치 상태를 유지합니다. 마우스/Touch를 놓아도 상태를 해제하지 않아 heartbeat·서버 snapshot·Chat/PlayerList 변화가 좌표에 자동 회피를 다시 적용하지 않습니다. `viewportChanged()`가 화면 크기나 필수 경계 변화를 감지하면 수동 상태와 진행 중 입력을 해제하고 자동 배치로 복귀합니다. ScreenGui의 안전 영역 origin 변화도 같은 방식으로 처리합니다.

위치는 기존 normalized X/Y 선호점을 재사용합니다. 영구 저장은 추가하지 않았으며 수동 입력·드래그 손잡이·색상·크기·Ready 표시·Finder·Debug 게이트는 유지합니다.

## 2. 변경 파일

- `src/shared/Utilities/PartyHUDGeometry.luau`: 새 dragPlacement·viewportChanged. 기존 자동 배치·치수·카드·행 계산은 그대로입니다.
- `src/client/Controllers/PartyHUD.luau`: 수동 상태 유지, drag clamp 선택, viewport/origin 변경 시 자동 배치 전환.
- `tests/PartyHUDDrag.spec.luau`: 새 드래그 회귀 7개 그룹.
- `docs/FINAL_PHASE_0_8_Party_HUD_Drag_Clamp.md`, `docs/implementation-reports/Phase_0_8_UI_Polish.md`: 이번 지시와 이전 보고 보존.
- `README.md`, `FOUNDATION_QA.md`, 이 파일: 최종 파일·자동/수동 수동 QA·6항목 보고.

## 3. 테스트 결과

- 기준 실행의 기존 169개 그룹과 최종 실행의 **176개 그룹 모두 통과**. 기존 테스트 파일은 바이트 그대로이며 자동 배치 회귀 19개를 유지했습니다.
- 공식 Luau 0.741: **44개 파일 문법 컴파일**, 순수 모듈 strict 분석 통과.
- 신규 7개: Chat 위 수동 좌표/같은 선호점의 자동 회피, PlayerList 위 수동 좌표/자동 회피, 네 방향 화면/TopBar 경계와 oversized 패널 clamp, 놓은 뒤 반복 갱신/CoreUI 변화의 수동 좌표 유지, resize 후 접근 가능한 자동 위치, 필수 Safe Area 변경 감지, zero startup/비정상 선호 좌표의 finite 처리.
- 기존 모든 테스트·서버·테마·입력 style·Debug·Party/Expedition 계약이 이전 커밋과 바이트 동일함을 확인했습니다. 소스 변경은 HUD와 Geometry 두 파일뿐입니다.
- Rojo 7.7.1 빌드와 **29개 스크립트/모듈 경로·타입·소스 일치**를 확인했습니다. 공유 소스·전체 ZIP·Studio 파일도 원본과 바이트 단위로 검증했습니다.
- git diff 공백 검사 통과. 실제 Roblox 이벤트 실행과 별도로 로직·문법·빌드 결과를 보고합니다.

## 4. 실제 Studio 미검증 항목

기존 UI의 정상 동작은 사용자 확인입니다. 이 환경에서는 Studio에 연결할 수 없어 **이번 변경 후 PC/Touch 수동 드래그·놓은 뒤 유지·resize 전환**의 실제 엔진 실행을 확인하지 못했습니다.

[FOUNDATION_QA.md](FOUNDATION_QA.md)의 최종 Drag Clamp 절차로 Chat/PlayerList 위에 놓기, heartbeat/파티 응답 후 유지, 화면 네 모서리·세로/가로 resize·Safe Area 변경 후 접근성과 자동 회피를 확인합니다. 수동 배치에서 CoreUI와 겹치는 것은 사용자가 선택한 정상 동작입니다.

Windows PC 직접 설치는 미수행입니다. `MonCook_Phase_0_8_Final_Source.zip`을 별도 임시 폴더에 풀어 기존 `Install-LocalProject.ps1`을 실행하면 `C:smallsizewakMonCook`과 `C:smallsizewakMonCook_LocalRepositoryMonCook`에 백업 복사합니다. Published/API·실제 원정 콘텐츠의 이전 미검증 범위는 그대로입니다.

## 5. TODO

- 최신 `MonCook_Phase_0_8_Final.rbxlx`에서 위 드래그/resize만 수동 판정합니다.
- 기존 자동 배치의 PlayerList 추정 영역과 화면 전체 Chat fallback의 실제 화면 판정은 이전 보고를 따릅니다.
- **Phase 0.8 최종 수정에서 작업을 종료**합니다. 다른 Party/Expedition 기능이나 새 게임 시스템을 진행하지 않습니다.

## 6. 다른 브랜치 영향

변경은 `MonCook/`의 표시 계층·새 UI 회귀·문서로 제한했습니다. 기존 feature 브랜치와 Draft PR #1을 갱신하고 main·다른 게임은 유지합니다.

PartyService·Public/Private·Finder 서버·ReadyCheck·ExpeditionSession·FakeTeleport·Restaurant Session·DataService·저장/경제/migration·Remote action/payload는 바뀌지 않습니다. 테마·버튼 시각 상태·기존 169개 테스트와 Debug 기본 false/Studio 게이트도 그대로입니다.

표시 API에는 `dragPlacement()`와 `viewportChanged()`만 추가합니다. 기존 placement()/measure() 호출자는 기존 자동 회피를 유지합니다. 사용자 PC 복사는 설치 스크립트가 필요하며 공유 최종 패키지와 이전 UI Polish 패키지를 함께 보관합니다.
