# MonCook — The Last Recipe

Roblox Studio / Luau 프로젝트입니다. 여러 게임이 들어 있는 `Gameproject1`에서 MonCook의 문서와 코드는 이 폴더에 모읍니다.

설계는 [CODEX_START_HERE.md](docs/LastRecipe_Codex_Design/CODEX_START_HERE.md)부터 읽습니다. 첨부된 설계 1.1은 [통합 기준 문서](docs/The_Last_Recipe_ALL_IN_ONE_CODEX_SPEC.md)와 분리 문서에 반영했습니다. 이전에 변경된 원본은 `docs/archive/design-lock-1.0/`에 보관했습니다. 이번 최종 수정은 [HUD Drag Clamp 지침](docs/FINAL_PHASE_0_8_Party_HUD_Drag_Clamp.md)입니다. 기존 [UI Polish 지침](docs/NEXT_CODEX_INSTRUCTION_Phase_0_8_UI_Polish.md)을 유지합니다. 기능 골격은 기존 [Phase 0.8 지침](docs/NEXT_CODEX_INSTRUCTION_Phase_0_8.md)을 따릅니다.

## 현재 구현 — Phase 0.8 UI Polish

기존 Foundation 0.1–0.7의 저장·프로필 잠금·파티·Restaurant escrow·정산·텔레포트 골격을 유지하고 Phase 0.8을 추가했습니다.

- 반투명 웜브라운 파티 HUD, 최대 4명 세로 축소 스택과 리더 왕관
- PC/Touch 드래그 손잡이와 Safe Area·화면 변경 보정
- 모집 상태 오른쪽 참가 버튼이 있는 compact Finder 카드
- 재사용 가능한 Normal/Hover/Pressed/Disabled 버튼 테마
- 현재 Hearthcross 서버의 공개 파티 찾기와 비공개 파티 초대
- Activity/Target 선택과 `함께 이동 / 응답 중 / 이번엔 남음` 준비 상태
- 선택한 멤버만 이동하는 Expedition 상태·FakeTeleport·결과 선택
- Repeat / HostRestaurant 선택 후 새 JOIN/STAY 동의 확인, Hearthcross 복귀
- Studio와 `Testing.ShowFoundationDebugUI == true` 조건에서만 보이는 기존 큰 Debug UI
- Quick Match의 Config hook과 사용 불가 인터페이스

Expedition은 **Studio FakeTeleport 골격**입니다. 실제 사냥·Twin Ogre 전투·전리품·보상은 아직 없습니다. Published Expedition 진입은 서버에서 차단합니다. Restaurant 정산은 기존과 같이 Gold/Renown 0, 맡긴 식재료 전량 반환입니다. 데이터 스키마와 migration은 그대로입니다.

```text
docs/LastRecipe_Codex_Design/  설계 1.1 분리 문서
docs/archive/                변경 전 설계 원본
src/shared/                  Config·타입·기본값·migration·표시 로직
src/server/Services/         저장·파티·세션·원정·이동 서비스
src/server/Adapters/         Roblox API / Studio 저장소
src/server/ServerConfig.luau Place ID·저장소·런타임 설정
src/client/Controllers/      파티 HUD·네트워크 연결·Studio Debug UI
tests/                       순수 로직·실패·동시 요청 회귀 테스트
tools/                       검증 및 PC 복사 스크립트
```

사용자가 기존 Phase 0.8 파티 기능의 Studio 정상 동작을 확인했습니다. 이번 UI Polish의 실제 화면·드래그·모바일 확인은 별도 QA가 필요합니다. Party·ReadyCheck·원정·저장·경제 계약은 이번 작업에서 변경하지 않습니다.

자동 배치는 Chat·PlayerList를 피합니다. 사용자 드래그는 해당 영역 위에도 놓을 수 있으며 놓은 뒤 유지합니다. 화면 크기나 필수 Safe Area가 바뀌면 안전한 자동 위치로 보정합니다.

## Studio에서 확인

공유 패키지의 `MonCook_Phase_0_8_Final.rbxlx`를 열고 **Server & Clients**로 2–4개 클라이언트를 시작합니다. 기본 HUD에는 Party ID 입력칸이 없습니다. 공개 파티는 Finder 카드로 참가하고, 비공개 파티는 같은 서버 플레이어에게 초대합니다. 호스트가 이동을 제안하면 다른 멤버는 함께 이동 또는 이번엔 남음을 선택합니다.

Studio는 메모리 저장소와 FakeTeleport를 사용하며 플레이어마다 HornboarMeat 5개·Salt 5개를 테스트용으로 줍니다. 원정 목표를 선택해 이동하고 호스트의 원정 결과 버튼으로 결과 상태와 세 가지 목적지를 확인할 수 있습니다. FakeTeleport는 같은 서버에서 위치 상태만 바꿉니다.

기존 Debug UI가 필요하면 테스트 시작 전에 `src/shared/Config/Definitions.luau`의 `Testing.ShowFoundationDebugUI`를 `true`로 바꿉니다. 기본값은 `false`이며 Published에서는 항상 숨깁니다.

Rojo를 사용하는 경우 이 폴더에서 실행합니다.

```sh
rojo build default.project.json -o MonCook_Phase_0_8_Final.rbxlx
rojo serve default.project.json
```

Published Restaurant 테스트에는 같은 Experience의 World/Restaurant Place ID를 `ServerConfig.luau`에 넣고 두 Place에 같은 코드를 배치해야 합니다. 현재 ID는 `0`입니다. ExpeditionPlaceIds는 후속 연결용이며 실제 Expedition 서버 도착·세션 복구는 아직 구현하지 않았습니다. 자세한 판정 기준은 [QA 안내](FOUNDATION_QA.md)를 따릅니다.

## 로직 검증

공식 Luau CLI가 PATH에 있는 환경에서 실행합니다.

```sh
python tools/run_foundation_tests.py
```

원본 Luau 문법을 컴파일하고, 임시 사본의 require 경로를 CLI용으로 변환해 순수 모듈의 strict 타입 검사와 테스트를 실행합니다. Roblox 엔진·실제 API·화면 검증은 별도입니다. 결과와 남은 작업은 [작업 상태](IMPLEMENTATION_STATUS.md)에 기록했습니다.

## Windows PC 보관

`MonCook_Phase_0_8_Final_Source.zip` 전체를 임시 폴더에 풀고 [프로젝트 설치 안내](tools/LOCAL_PROJECT_INSTALL.md)를 실행하면 소스·문서·테스트를 다음 두 위치에 복사합니다.

- `C:\smallsize\wak\MonCook`
- `C:\smallsize\wak\MonCook_LocalRepository\MonCook`

변경된 기존 파일은 백업하고 추가 파일은 보존합니다. 이 클라우드 환경에서는 PC의 `C:` 드라이브에 직접 접근할 수 없으므로 실제 PC 복사는 설치 스크립트를 실행해야 완료됩니다. ZIP에 포함한 `.rbxlx`는 별도로 열 수 있습니다.
