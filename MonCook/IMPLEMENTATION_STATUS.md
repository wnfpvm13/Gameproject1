# MonCook 작업 상태 — Phase 1 Correction

기록일: 2026-10-06 (한국 시간). 브랜치 `integration/hunting`, [Draft PR #2](https://github.com/wnfpvm13/Gameproject1/pull/2). **수정 구현·자동 검증 완료 / 실제 Studio acceptance 보류**. 사용자 Studio 확인에서 기존 공격 모션·구형 모델·hit readability가 거절되어 수정합니다. [이전 Phase 1 보고](docs/implementation-reports/Phase_1_Initial_Hunting.md)는 당시 기록으로 보존하며, 현재 아트 승인을 의미하지 않습니다.

[첨부 재설계/애니메이션 지침](docs/PHASE_1_CORRECTION_Animation_Hornboar_Redesign.md)과 [공격 판정 지침](docs/PHASE_1_CORRECTION_Combat_Hitbox_Range.md)을 함께 적용했습니다. [최신 수동 QA](CORRECTION_QA.md)를 먼저 따릅니다.

## 1. 구현 내용

기존 Body/Horn query 뒤에 박스 중심만 range/arc로 검사하던 부분을 실제 **전방 sector와 upright oriented box의 교차 표면** 검사로 바꿨습니다. 탐색 broadphase는 box, 최종 검증은 원형 reach/두 angular boundary/수직 제한과 서버 LOS입니다. 돌아온 표면점에도 CombatService의 거리/arc 검증을 유지합니다. Root가 뒤에 있는 몬스터는 별도 제외하며 client가 hit/damage/part를 지정하지 못합니다.

Body: center `(0,2.65,-0.55)`, size `(5.6,4.7,10.6)`. 긴 torso·shoulder·neck·head·leg gap을 포함하며 시각보다 약간 관대합니다. Horn: center `(0,4.45,-5.25)`, size `(2.75,2.9,4.5)`로 root/forward tip을 포함합니다. 서버에서 유효한 접촉만 모은 뒤 Horn을 우선하여 body center 밖의 올바른 Horn hit가 사라지지 않습니다. 공격당 encounter 한 번, 뿔 파괴 즉시 query false를 유지합니다.

Basic reach **5.8 studs / 96°**, Heavy **6.8 / 108°**, Heavy PartPower 55를 Config/TODO_BALANCE로 둡니다. 약한 assist는 화면에 보이는 전방 가까운 surface를 hint로 고르고 서버가 다시 검사합니다. assist 최대 12°, 전체 facing correction 최대 18°이며 lock-on/자동 공격은 없습니다.

## 2. 코드 변경 / 변경 파일

- `HuntingHitGeometry`: sector/OBB surface contact·Horn priority·near-surface aim·Studio debug gate. `HuntingMath`: bounded turn 및 경계 부동소수점 보정.
- `CombatService`: action별 reach/arc, bounded server assist, rear target 제외, trusted hit의 위치/AttackType 추가. 기존 sequence/rate/weapon/alive/window/once 검증 유지.
- `MonsterService`: accepted-hit Reaction/Part/Heavy를 표시 event로 추가, Light/Horn/Heavy/Break 구분 및 Heavy 0.24초 stagger. 기여/보상/receipt IDs·Core/Death 지급 계약 유지.
- `HuntingRuntime`/`CombatDebugView`: volume 접촉/LOS, 서버 확정 feedback, 실제 attack window attrs, Studio flag + IsStudio 이중 debug gate. 기본 false·Published 강제 비표시.
- `CombatAnimation`/`HuntingAnimation`/`HuntingAnimator`: torso/root·waist·neck·양팔·elbow/wrist·cleaver, 네 다리/하퇴, distinct reactions/Death.
- `HuntingHitFeedback`/`CombatPresentationConfig`: Body/Horn 다른 spark·pitch/volume, Heavy 강화, death particles. Miss는 server hit event가 없어 효과도 없음.
- `ImportedHornboarRig`/`HuntingAssetBinder`/`HuntingAnimator`: 사용자가 Studio에서 FBX로 가져온 `MeshPart + Motor6D + AnimationController` Hornboar를 직접 바인딩/포즈. 런타임 EditableMesh 생성 경로 제거.
- `art/blender/redesign_hornboar.py`, `hornboar_design.py`, export/data/runtime/manifest/FBX/GLB/blend/previews/audio: 실제 모델 교체와 재현 pipeline.
- `CombatReadability.spec` 신규 28그룹; `HuntingIntegration.spec`의 contact fixture를 점에서 실제 box 계산으로 교체. 기존 8개 시나리오/보상 assert는 유지.
- 최신 QA/지침/README/본 보고/이전 보고 archive, artifact validator 보강.

## 3. 제작한 Asset / Asset별 상태

기존 구형 중심 Hornboar는 승인된 V1로 취급하지 않고 제거했습니다. 새 모델은 authored longitudinal mesh cross-sections로 만든 가로로 긴 torso·큰 어깨/낮은 후면·작고 무거운 head·protruding snout·작은 귀/낮은 눈·Upper→Lower→Hoof 네 다리입니다. 이마에서 굵게 시작해 앞/위로 휘고 가늘어지는 ivory Horn, 별도 stump, 절제한 magic accent를 사용합니다.

`MON_Hornboar_V1`: **재설계 V1 candidate, Studio 시각 승인 대기**. Cleaver 및 기존 재료 4종/환경 10종은 이전 V1 상태를 유지합니다. Source Close/Medium/Far/AvatarScale renders를 실제 생성·확인했습니다. 이 renders는 Studio 화면이 아닙니다. [Art 보고](art/README.md)에 구분합니다.

Body/Horn/Heavy original WAV도 생성했습니다. 현재 game sound는 업로드 ID 없이 동작하는 built-in landing sample의 pitch/volume를 구분하며, authored WAV의 Roblox 업로드는 미수행입니다.

## 4. Triangle / Rig / Runtime 표현

새 Hornboar **4,248 triangles**, 44 source objects, **14 bones**. Duplicate vertices/zero-area bevel faces를 정리하고 모든 exported face의 면적·index·palette·source SHA를 검증했습니다. 3,000–6,000 budget을 만족합니다. Cleaver는 기존 2,168 triangles입니다.

Hornboar source/FBX의 Root/Spine/Neck/Head/4 upper legs/4 shins/Horn/Tail hierarchy를 보존했습니다. Studio-imported Hornboar는 `RootPart + MeshPart + Motor6D + AnimationController` rigid rig입니다. 서버는 이 imported visual rig를 복제하고 별도 invisible Body/Horn gameplay hitbox를 붙입니다. Animation은 imported Motor6D에 semantic mapping으로 직접 적용합니다. `EditableMesh`/`CreateMeshPartAsync` runtime 생성은 제거했습니다. 원본 `.rbxm`의 크기 76,575 bytes, SHA-256 `df3ef039ba0141c7227cdd560dd64ecd1f59341ed0ba50a3695691f9a4782578`를 asset contract로 기록했습니다.

## 5. Animation / Hit feedback

Basic1 right→left 횡베기, Basic2 반대 방향, Basic3 overhead, Heavy 긴 windup/양팔 support/큰 torso 회전과 weight shift, Dodge lean을 구현했습니다. 캐릭터의 grip만 돌리는 이전 방식 대신 RootJoint/Waist/Neck/Shoulders/Elbows/Wrist/Grip에 additive poses를 적용합니다. R6/R15 rest axes를 retarget하고 PreAnimation에서 이전 delta를 제거한 뒤 PreSimulation에서 기본 Animator pose 위에 적용합니다.

서버가 보낸 Start/HitStart/HitEnd/End timestamp를 같은 Windup→Hit→Recover 함수에 사용합니다. Client Animation은 damage를 결정하지 않습니다. 실제 blade 최대 reach와 최초 damage의 화면 동기화는 Studio로 최종 판정해야 합니다.

Hornboar source/실제 FBX reimport에 **13 actions**: Idle/Walk/Run/Alert/ChargeWindup/Charge/Headbutt/LightHit/HeavyHit/HornHit/HornBreak/Stagger/Death. Runtime은 joints를 state/time/reaction으로 pose합니다. Source action의 uploaded AnimationTrack playback을 주장하지 않습니다.

Body는 warm spark·short flinch, Horn은 cyan thin spark·head recoil, Heavy는 큰 spark/recoil와 short stagger, HornBreak는 강한 head recoil·intact→stump·VFX를 사용합니다. Death는 쓰러짐·밝은 particles·fade 뒤 despawn입니다. 개인 loot cosmetic만 recoil/death가 시작된 뒤 표시하며 서버 지급/receipt 시점은 유지합니다.

## 6. 테스트 결과

**316개 그룹 PASS = 기존 288개 시나리오 + 신규 28개**. 기존 Foundation 176개 테스트 파일은 merge baseline과 바이트 동일합니다. 기존 Phase 1 보상 통합 8개 시나리오는 유지하고 기존 center-only contact fixture만 실제 box geometry로 갱신했습니다.

신규 검증: center가 범위/각도 밖인 surface/shoulder/flank, exact max range/외부, 뒤·옆·수직/diagonal broadphase corner, rotated box/inside/tangent, front/diagonal Horn, Horn priority/파괴 후 Body, Basic/Heavy 차이, Debug default/Release gate, 다수 box의 contact 범위 불변식, bounded mirrored assist/near-surface, rear overlapping target, 뿔 옆 Body, 서버 Heavy window, 3 combo full-body 차이/Heavy 양팔/rest/Dodge, distinct recoil/accepted hit only/duplicate.

Official Luau 0.741: **79개 syntax compile PASS**, 순수 모듈/테스트 strict 분석 PASS. Blender 4.3.2: 실제 16개 FBX reimport PASS, 새 Hornboar 4,248/14 bones/13 actions 확인. Rojo 7.7.1: **56개 runtime script/module 경로·타입·소스 일치**, 16 asset source/export·native skeleton/binding·정확한 topology/index/면적/palette/Body·Horn bounds·원본 회귀 보존 PASS.

실행 중 발견한 퇴화 face와 생성 데이터의 type complexity는 topology 정리/JSON packet으로 해결했습니다. 최종 검증에는 남은 실패가 없습니다. Roblox API의 실제 실행/클라이언트 이벤트·physics는 위 offline 결과와 구분합니다.

## 7. 실제 Studio 미검증 / acceptance

이 환경에서는 Studio 연결이 없습니다. 사용자 피드백은 수정 전 실제 플레이 결과이며, 수정 후 검증으로 간주하지 않습니다. [CORRECTION_QA.md](CORRECTION_QA.md)의 hit 12항목과 animation/art 18항목, 2–4인·R6/R15·Touch/Gamepad·attack timing·EditableMesh 생성/메모리/streaming·새 실루엣·Body/Horn feedback를 실제 실행해야 합니다.

특히 새 geometry packet/loader의 API 성공 여부, 첨부 재설계 시각 승인, 실제 무기/box 타이밍, built-in Horn sound의 읽힘, mobile 성능은 미검증입니다. **Phase 1 acceptance 완료를 선언하지 않습니다.**

## 8. 알려진 문제 / TODO

- Source rig와 runtime rigid MeshPart/Motor6D visual 사이의 변형·R6/R15 retarget 품질은 실제 장면에서 확인합니다. Source imported skinned-animation playback은 별도 후속 작업입니다.
- Box는 현재 pose의 conservative root-relative approximation입니다. Horn recoil 중 visual 차이를 QA로 측정하고 필요하면 Config/Binder 범위 안에서 조정합니다.
- Basic/Heavy 값은 TODO_BALANCE입니다. 낮은 frame rate/latency에서 window readability·mesh cache/mobile memory·streaming을 확인합니다.
- Authored WAV/audio IDs 및 최종 Horn impact tone은 추가 Art QA입니다. 현재 작은 소리는 builtin fallback이고 source만 만들어 놓은 무음 상태는 아닙니다.
- 기존 단순 AI 장애물 정체, 미확정 server-memory loot queue의 강제 종료/장기 저장 장애 유실 가능성, Published IDs/real teleport 미검증은 유지합니다. DataService/Inventory/Loot 경제 계약을 이번 수정으로 바꾸지 않았습니다.

## 9. 산출물

[Draft PR #2](https://github.com/wnfpvm13/Gameproject1/pull/2)를 갱신합니다. 공유 폴더 `/workspace/shared/MonCook`에 최신 source/art/docs 및 `MonCook_Phase_1_Correction.rbxlx`를 보관합니다. 이전 파일도 보존하되 이번 수동 QA는 Correction 파일을 사용합니다. 전체 소스 PC 설치 ZIP은 만들지 않습니다. Windows C: 직접 복사는 미수행입니다.

최종 place SHA256은 공유 `.sha256` 파일에 기록합니다. 소스 mirror와 원본 파일 바이트 일치 검증 후 전달합니다.

## 10. 다른 브랜치 / Phase 2 영향

변경은 MonCook/에만 있습니다. DataService·InventoryService·LootService·Party/Session/Expedition·Foundation core와 경제/저장/migration/receipt/remote intent fields는 유지합니다. Monster presentation event/optional hit metadata, Heavy short stagger, action reach/arc와 선택적 geometry injection만 확장합니다. 기존 feature 서비스 snapshot보다 최종 integration/hunting adapter/mesh/animation이 우선합니다.

후속 mesh 교체는 Root/Joint/Visual/HornIntact/HornBroken Binding과 server hitbox 계약을 보존해야 합니다. Cooking/Restaurant·새 몬스터·Expedition 실제 전투·Quick Match/Phase 2는 시작하지 않습니다. **수정 결과와 새 Studio 파일을 제공한 뒤 멈춥니다.**
