# MonCook 작업 상태 — Phase 1 Hunting Foundation + V1 Art

기록일: 2026-10-06 UTC. 상태: **구현·자동 검증 완료 / 실제 Studio acceptance 미검증**. Phase 2로 진행하지 않습니다.

[사냥 지침](docs/NEXT_CODEX_INSTRUCTION_Phase_1_Hunting_Foundation.md), [3D 추가 지침](docs/ADDITIONAL_PHASE_1_3D_ASSET_PRODUCTION.md), [공통 계약](docs/PHASE_1_HUNTING_CONTRACTS.md), [수동 QA](HUNTING_QA.md)를 따릅니다. 기존 [Phase 0.8 최종 보고](docs/implementation-reports/Phase_0_8_Final_Drag_Clamp.md)는 별도 보존합니다.

## 1. 구현 내용

World의 `Greenwood Outskirts_PLACEHOLDER`에 Config 기반 Hornboar 슬롯 2개와 V1 나무·바위·덤불·풀·그루터기·표지판을 배치했습니다. 일반 플레이어가 파티 없이도 같은 개체를 공격할 수 있습니다. SpawnZone/MaxAlive/RespawnDelay/MonsterId로 생성하며 매번 새 EncounterId를 사용합니다.

Starter Cleaver Basic 3연타·콤보 timeout reset·느린 Heavy/높은 PartPower·짧은 위치 Dodge/cooldown을 구현했습니다. PC M1/Q/F/I, Touch 3개 버튼, Gamepad R2/X/B를 같은 action abstraction으로 처리합니다. Space·Gamepad A 점프·Shift Lock은 유지합니다. 자동 공격·stamina·i-frame 의존은 없습니다. 약한 facing/target assist만 제공합니다.

서버가 actor·소유/장착 무기·살아 있음·World/travel 상태·rate/sequence·공격 window·range/arc·명시적 hitbox·line-of-sight를 검증합니다. 클라이언트는 Sequence/AttackType/선택 Facing·TargetHint만 전송합니다. 동일 공격의 Body/Horn 겹침은 개체당 한 번 처리합니다.

Hornboar는 Humanoid 없이 Idle/Roam/Alert/Chase/Windup/Attack/Recover/Stagger/Dead 상태를 사용합니다. Headbutt와 방향 고정/예고 있는 Charge, 별도 Body HP/Horn HP, 뿔 파괴·stump 전환·horn query 비활성, death/despawn/respawn을 연결했습니다. 서버 돌진과 Dodge는 장애물 검사로 이동을 제한합니다.

의미 있는 Body/Part damage의 최근 기여자별 독립 loot입니다. Meat 보장, Fat common/uncommon, Loin rare, 파괴 당시 기여자 Core를 지급합니다. 마지막 타격/Party 소속/근처 AFK로 독점하거나 무임승차하지 않습니다. Gold 드롭이나 물리 pickup은 없습니다. 최초 재료/기여자 Hornboar 처치 flags와 Analytics BindableEvent hook을 제공합니다.

기존 Ingredients/Materials numeric stack에 DataService.Update로 증가와 HuntingReceipt를 원자 저장합니다. roll은 한 번 고정하고 실패 시 재시도합니다. 지급 성공 후 개인 알림·재료 pop/move/fade가 발생합니다. 가방에는 두 탭·아이콘 placeholder·이름·수량을 표시합니다. 정상 종료 전 bounded flush를 추가했습니다.

## 2. 브랜치 / PR

사용자 승인으로 Foundation [PR #1](https://github.com/wnfpvm13/Gameproject1/pull/1)을 main에 병합했습니다. 기준 merge SHA는 `a8b3ad0fbd9beda30a1e73dfa84affc58c805648`이며 이 기준의 176개 테스트를 먼저 검증했습니다.

공통 계약 커밋에서 `feature/combat`, `feature/monsters`, `feature/inventory`를 나눠 해당 순수 서비스와 테스트를 구현하고 `integration/hunting`에 merge했습니다. 최종 Roblox 어댑터·클라이언트·아트·통합 hardening은 integration에 있습니다. 검토용 Draft PR은 integration/hunting → main입니다. Phase 1 PR은 자동 병합하지 않습니다.

## 3. 코드 변경 / 변경 파일

- `src/server/Services/{CombatService,MonsterService,LootService,InventoryService}.luau`: 전투·AI/기여도·고정 roll/재시도·원자 stack/receipt.
- `src/server/Adapters/{HuntingRuntime,HuntingAssetBinder,GreenwoodField}.luau`: 인증/API 주입·서버 physics·개인 network·모델 binding·필드.
- `src/server/Foundation.server.luau`: additive World startup 및 profile release 전 flush hook.
- `src/shared/Config/{HuntingConfig,HuntingUIStyle,GreenwoodConfig,Definitions,Registry}.luau`: TODO_BALANCE, stable catalog 확장·validation·presentation 상수.
- `src/shared/Types/{Hunting,PlayerData}.luau`, `Remotes/Definitions.luau`, `Utilities/{HuntingMath,HuntingContracts,HuntingPresentation,HuntingAnimation,PlayerDataDefaults}.luau`: 새 계약·별도 network·순수 geometry/input/layout·기존 starter 설명.
- `src/client/Controllers/Hunting*.luau`: 입력·HUD·inventory·개인 visual·서버 timestamp 기반 pose.
- `tests/{CombatService,MonsterService,LootService,InventoryService,HuntingContracts,HuntingPresentation,HuntingIntegration}.spec.luau`: 신규 112개 그룹.
- `art/`: 실제 제작 source/export/runtime 16세트, 측정 manifest·reimport 결과·4개 render.
- `default.project.json`, `.gitignore`, `tools/validate_hunting_artifacts.py`: 모델 포함·native 모델 추적·빌드 serialization 검증.
- README/본 보고/HUNTING_QA/설계 DATA_SCHEMA·TECH_ARCHITECTURE/첨부 지침·공통 계약·과거 보고 archive.

기존 DataService·PartyService·SessionService·ExpeditionService·PartyHUD 파일과 기존 테스트 파일은 main 기준과 바이트 동일합니다. 새로운 network는 MonCookHuntingNetwork이고 기존 Foundation remote/payload는 유지합니다. 다른 게임의 파일은 변경하지 않습니다.

## 4. 제작한 3D Asset

실제 Blender 4.3.2에서 생성·저장·FBX/GLB export 후 **16개 FBX를 재가져와 검증**했습니다. 단순 생성 script만으로 완료 처리하지 않았습니다.

Hornboar, Starter Cleaver, HornboarMeat/ArcaneFat/MarbledLoin/HornCore, Tree A/B/C, Rock A/B/C, Bush/Grass/Stump/Sign입니다. `.blend`/FBX/GLB 각 16개와 대응 `.rbxmx` 모델 16개를 보존했습니다. [에셋 보고](art/README.md)에 각 파일·triangle·native part 수·재현 명령을 기록했습니다.

`.rbxlx`에는 바로 열 수 있는 **native Part/WedgePart V1 equivalents**를 포함했습니다. Blender 메시가 이미 Roblox에 import/upload된 것으로 보고하지 않습니다. Root/Visual/Gameplay/rig와 Binding tag를 분리하여 후속 mesh 교체가 AI·보상 코드를 바꾸지 않도록 합니다.

## 5. Asset별 상태

16개 모두 **V1**, Final은 없습니다. Hornboar/Cleaver는 `_V1` 실제 game model이며 greybox-only 상태로 끝내지 않습니다. 재료/환경도 V1입니다. 테스트 필드 이름만 지침대로 `_PLACEHOLDER`를 유지합니다. Inventory 아이콘과 custom SFX는 placeholder입니다. 전체 asset별 표는 [art/README.md](art/README.md)를 참조합니다.

## 6. Triangle 수 / Rig 상태

Hornboar: **5,888 source triangles**, 58 mesh objects, ten bones, native **86 BaseParts + 2 hitboxes**. Cleaver: **2,168 source triangles**, 21 mesh objects, native 22 BaseParts. 두 source budget 모두 만족합니다. Meat/Fat/Loin/Core는 각각 504/504/1,044/240 triangles입니다. Native parts의 rendering 비용은 이 source triangle 값과 별개입니다.

Hornboar bones는 Root/Spine/Neck/Head/4 legs/Horn/Tail이고 FBX reimport에서 모두 확인했습니다. Native rig는 ten joint nodes와 nine Motor6Ds입니다. 각 visual의 combat collision은 껐으며 별도 Body/Horn hitbox를 서버가 생성합니다. 모델 내부 경로 대신 stable Binding으로 intact/broken horn과 joints를 찾습니다.

## 7. Animation 상태

Blender source와 실제 FBX reimport에 Idle/Walk/Run/Alert/ChargeWindup/Charge/Headbutt/HitReact/Stagger/Death ten actions가 있습니다. Source vertex rig binding도 확인했습니다.

현재 game model은 서버 state/time을 읽는 client Motor6D procedural V1 poses와 Cleaver grip swing을 사용합니다. Uploaded FBX AnimationId playback은 구현/검증 완료로 주장하지 않습니다. Close/Medium/Far Hornboar와 Cleaver source renders를 실제 생성·시각 확인했습니다. 이 이미지는 Studio 화면이 아닙니다.

## 8. Studio 테스트 결과 / 실패·미검증 / 알려진 문제

**Studio 연결이 없어 실제 엔진 플레이를 실행하지 못했습니다.** 2–4인 동시 사냥/개인 loot, Touch/Gamepad 실제 조작, R6/R15 grip, animation/hitbox/telegraph 동기화, broken horn visual, 모바일 세로/가로·Chat/PlayerList/Safe Area·streaming/performance, Published persistence는 [HUNTING_QA.md](HUNTING_QA.md)에 미검증으로 남깁니다. 이 확인 전 Phase 1 acceptance 완료를 선언하지 않습니다.

- Native Horn hitbox는 server root에 고정된 근사 box여서 animated horn과의 차이를 Studio에서 측정해야 합니다. Native part 수와 원거리 실루엣도 모바일에서 확인해야 합니다.
- AI는 단순 추적/장애물 blockcast로 벽에서 막힐 수 있습니다. 새로운 pathfinding 시스템은 추가하지 않았습니다.
- Custom hit/break SFX는 placeholder입니다. Horn break particle VFX는 포함했습니다. Imported mesh/material/rig·uploaded animations·asset ownership은 후속 Art QA입니다.
- 미확정 reward queue는 서버 메모리입니다. 성공한 grant는 durable receipt로 중복 방지하지만, 저장 장애/정상 종료 timeout/프로세스 강제 종료 시 미확정 보상이 유실될 수 있습니다. 정상 종료에는 release 전 최대 5초 flush를 시도합니다.
- Analytics는 hook/첫 flags만 준비했습니다. 실제 외부 전송·대시보드·전투 balance는 미완료입니다.
- 기존 Published Place IDs 0/실제 teleport·Expedition actual combat 제한과 Restaurant skeleton은 유지합니다. Windows PC에 직접 복사하지 못했습니다. 요청 지침에 따라 새 전체 소스 ZIP은 생성하지 않습니다.

## 9. 자동 테스트 수 / 검증 결과

- **288개 그룹 PASS = 기존 176 + 신규 112**. 기존 모든 테스트 파일 바이트 보존 검증 PASS.
- 신규: Combat 24, Monster 24, Inventory 19, Loot 16, Contracts 13, Presentation 8, Integration 8.
- Official Luau 0.741: **71개 Luau 파일 syntax compilation PASS**, 순수 모듈/테스트 strict 분석 PASS. Roblox API가 필요한 controller/adapter의 엔진 타입·실행은 별도입니다.
- 실제 순수 서비스 통합으로 2 contributor horn/core/death/독립 loot/persistence/duplicate/dead/respawn·늦은 contributor·장애물·저장 실패·ack 유실·yield 중 재진입을 검사했습니다. 이 결과는 Roblox physics 실행을 대신하지 않습니다.
- Blender 4.3.2: 16개 실제 FBX reimport, triangle/object·rig/actions·vertex binding PASS; source render 4개 생성/확인.
- Rojo 7.7.1: Studio QA place build PASS. 16개 native model/reference/rig binding, **49개 runtime script/module 경로·타입·소스 일치**, 기존 테스트 보존 PASS.
- git diff 공백 검사 PASS. 공유 source mirror와 최종 place checksum은 전달 파일과 함께 기록합니다.

## 10. 남은 Art TODO / TODO / Phase 2·다른 브랜치 영향

우선 HUNTING_QA 15항목·2–4인·PC/Touch/Gamepad·뿔/리그/판정/성능을 실제 Studio에서 확인합니다. 실패 시 Phase 1만 수정합니다. 이후 필요하면 Blender mesh/animation upload, primitive 비용 개선, custom SFX·최종 icon, V2/Final art를 계획합니다. 현재 수치는 전부 TODO_BALANCE입니다.

Phase 2는 동일 ingredient IDs/stack bucket·server-only mutation·receipt와 RecipeConfig를 재사용할 수 있습니다. Cooking 소비나 Restaurant 매출은 아직 추가하지 않았습니다. Owned weapon instance 계약·Binding 기반 asset 교체·SpawnZone·low contribution 정책을 유지해야 합니다. 새 몬스터는 Config/binder를 확장할 수 있지만 이 Phase에서 구현하지 않습니다.

기존 공통 Config key는 유지하고 Combat/Spawn/Hunting family 및 선택적 HuntingReceipts를 추가했습니다. SchemaVersion 1 및 기존 migration/Restaurant escrow/SettlementReceipts/경제 계약은 그대로입니다. Foundation startup/release hook을 수정하는 후속 브랜치는 사냥 flush 순서를 유지해야 합니다. Phase 1 feature branches는 서비스 단위 snapshot이고 최종 integration adapters/presentation을 함께 병합해야 합니다.

**Phase 1 구현 보고 상태에서 멈춥니다. Studio acceptance와 PR review/merge는 후속 판정이며 Phase 2 개발은 시작하지 않습니다.**
