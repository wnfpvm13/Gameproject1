# MonCook — The Last Recipe

Roblox Studio / Luau 프로젝트입니다. 여러 게임을 담은 `Gameproject1`에서 MonCook의 코드·문서·에셋은 이 폴더에 모읍니다. 설계는 [CODEX_START_HERE.md](docs/LastRecipe_Codex_Design/CODEX_START_HERE.md)부터 읽습니다.

## 현재 구현 — Phase 1 Correction

최신 [애니메이션/모델 지침](docs/PHASE_1_CORRECTION_Animation_Hornboar_Redesign.md)과 [판정 지침](docs/PHASE_1_CORRECTION_Combat_Hitbox_Range.md)을 반영했습니다. Basic/Heavy의 전방 surface 판정·전신 공격·피격 feedback·Blender Hornboar 메시를 수정했습니다. **새 모델은 Studio 승인 대기 V1 candidate**이며 [CORRECTION_QA.md](CORRECTION_QA.md)의 API 실행 조건과 수동 판정을 먼저 확인합니다.

Foundation PR #1을 사용자 승인으로 main에 병합한 뒤 `integration/hunting`에서 구현했습니다. [사냥 지침](docs/NEXT_CODEX_INSTRUCTION_Phase_1_Hunting_Foundation.md)과 [3D 제작 지침](docs/ADDITIONAL_PHASE_1_3D_ASSET_PRODUCTION.md)을 함께 적용했습니다.

- World의 Greenwood 공유 사냥터, Config 기반 Hornboar 생성·AI·돌진 예고·리스폰
- Starter Cleaver의 3연타·강공·위치 회피, PC/Touch/Gamepad 입력
- 별도 Body/Horn HP와 한 번만 발생하는 뿔 파괴
- 기여자별 독립 Personal Loot와 기존 Ingredients/Materials 인벤토리의 서버 저장
- 재료 탭·수량·희귀 획득 알림과 개인 3D 획득 연출
- Hornboar·Cleaver·재료 4종·환경 10종, 총 16개 에셋(Hornboar는 재설계 V1 승인 대기)

자동 테스트와 빌드 검증은 통과했습니다. **Studio 2–4인·모바일·실제 판정/시각 동기화는 미검증**이며 Phase 1 플레이 승인 조건은 아직 판정하지 않았습니다. 상세 결과·제약·후속 작업은 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)에 있습니다.

Phase 0.8 Party HUD·Finder·ReadyCheck·수동 드래그는 유지합니다. 자동 배치는 Chat/PlayerList를 피하고, 수동 드래그는 해당 영역 위에도 놓을 수 있습니다. 화면/Safe Area가 바뀌면 자동 배치로 보정합니다. Debug 패널 기본값은 false이며 Studio 전용입니다.

실제 사냥은 Shared World에만 있습니다. Expedition은 기존 FakeTeleport 골격이고 Published 진입이 차단됩니다. Restaurant도 기존 골격·식재료 escrow/반환만 유지하며 Cooking·매출·새 몬스터·Gold 드롭·Quick Match는 이번 범위에 없습니다. [Foundation QA](FOUNDATION_QA.md)와 [Phase 0.8 최종 보고](docs/implementation-reports/Phase_0_8_Final_Drag_Clamp.md)를 보존했습니다.

## Studio에서 확인

`MonCook_Phase_1_Correction.rbxlx`를 열고 **Server & Clients 2–4명**으로 실행합니다. 초록 사냥터 표지판 너머에 Hornboar가 생성됩니다. PC는 M1 공격 / Q 강공 / F 회피 / I 가방, Gamepad는 R2 / X / B, Touch는 화면 버튼입니다. 기본 이동·점프·Shift Lock을 유지합니다.

Studio는 기존 메모리 저장소를 사용하고 플레이어마다 HornboarMeat 5개·Salt 5개를 테스트용으로 제공합니다. 실행 중 지급/중복 검증은 가능하지만 Stop 후 저장소가 사라집니다. Published DataStore 검증과 실제 텔레포트는 별도입니다. World/Restaurant Place ID 기본값은 `0`입니다.

[HUNTING_QA.md](HUNTING_QA.md)의 15개 플레이 절차와 멀티플레이·모바일·아트 확인표를 따릅니다. 이 환경에서는 Studio나 Windows C: 드라이브에 직접 접근할 수 없습니다. 이번 지침에 따라 새 전체 소스 설치 ZIP은 만들지 않습니다. PC에서는 Git 저장소의 해당 브랜치를 받아 기존 개인 보관 폴더에도 복사할 수 있습니다.

```sh
rojo build default.project.json -o MonCook_Phase_1_Correction.rbxlx
rojo serve default.project.json
```

## 검증과 에셋

```sh
python3 tools/run_foundation_tests.py
python3 tools/validate_hunting_artifacts.py --place MonCook_Phase_1_Correction.rbxlx
```

공식 Luau CLI로 문법·순수 모듈 strict 분석·316개 테스트 그룹을 실행합니다. 검증 도구는 기존 176개 테스트 파일 보존, 네이티브 모델 참조와 빌드된 56개 스크립트 소스 일치를 확인합니다. Roblox 엔진 검증과 구분합니다.

`art/blender/`에 실제 `.blend`, `art/exports/`에 FBX/GLB, `art/runtime/`에 Rojo가 포함하는 `.rbxmx`가 있습니다. **Hornboar는 실제 Blender topology를 EditableMesh MeshParts로 생성하고, 나머지는 기존 Part/WedgePart V1입니다.** 새 runtime API/모델은 실제 Studio에서 미검증이며 업로드된 asset/AnimationId로 보고하지 않습니다. 제작·재가져오기·triangle/리그 수치와 교체 방식은 [art/README.md](art/README.md)를 따릅니다.

```text
docs/                   설계·지침·계약·과거 보고
src/shared/             Config·타입·순수 로직
src/server/Services/    Foundation·전투·몬스터·개인 보상·인벤토리
src/server/Adapters/    Roblox API·필드·에셋 바인더
src/client/Controllers/ Party HUD·사냥 입력/표시
art/                    제작 소스·출력·런타임 V1·측정·미리보기
tests/                  기존 회귀 및 Phase 1 테스트
tools/                  검증·기존 PC 복사 도구
```
