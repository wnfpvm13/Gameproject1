# Phase 1 Studio QA / import 절차

현재 판정: **미검증**. Offline Luau/Blender/export 검증은 실제 Roblox 플레이를 대신하지 않는다.

## 준비 / V2 runtime 편입

1. `integration/hunting`의 최신 push된 commit을 checkout하고 Rojo로 `MonCook/default.project.json`을 sync/build한다. 새 local QA place에서 시작하며 기존 place를 덮어쓰지 않는다.
2. Studio 3D Importer에서 `art/generated/Monsters/Hornboar/V2/export/MON_Hornboar_V2.fbx`를 import/upload한다. 경험과 같은 creator/그룹이 mesh/texture/animation을 소유하도록 한다. 기본 cuboid/EditableMesh로 대체하지 않는다.
3. FBX의 5 meshes와 14 bones, diffuse 512 atlas, intact/broken variants를 확인한다. Material split 시 6~7 MeshParts까지 허용한다. 자동 rescale을 끄고 길이 약 11.68 / 높이 5.87 / 폭 5.60 studs 및 지면 정렬을 확인한다.
4. import한 모델을 선택하고 `tools/InstallHornboarV2.studio.luau`를 읽은 후 EDIT Command Bar에서 실행한다. script는 선택 모델을 clone하고 기존 V2 덮어쓰기를 거부한다. `ReplicatedStorage.Assets.Monsters.MON_Hornboar_V2`에 RootPart, visual welds, Binding과 준비 marker를 만든다.
5. 그 모델을 `art/runtime/Monsters/MON_Hornboar_V2.rbxm`으로 저장하고 Git에 추가한다. 현재 `init.meta.json`은 live sync가 수동 import 모델을 지우지 않게 보존한다. V1 파일은 삭제하지 않는다.
6. Runtime binder는 RootPart, 4~7 MeshParts, 14 semantic bones, 두 horn variant 및 준비 marker를 검사한 뒤 V2를 사용한다. 누락/불완전 모델은 V1 경로를 유지한다. 현재 저장소의 V1 `.rbxmx`에는 MeshPart가 없으므로, V1 비교/실행에는 기존 사용자 Studio import를 복원해야 한다.

## Player AnimationTrack / publication

1. Studio R15 rig를 선택한다. `tools/PreparePlayerClips.studio.luau`로 5 source clips를 그 rig의 실제 C0 축으로 retarget한다.
2. `MonCookPlayerClipsForPublish`의 Basic1/2/3, Heavy, Dodge를 preview하고 경험 creator 소유로 publish한다. 발·무릎·골반·허리·양팔 변형과 Cleaver grip을 확인한다.
3. IDs를 `src/shared/Config/HuntingAnimationConfig.luau`의 `Player`에 넣는다. 개발 Studio에서는 빈 ID에 대해 local KeyframeSequence 등록/AnimationTrack preview가 가능하다. 이 임시 hash ID는 production 업로드를 대신하지 않는다.
4. 실제 track load 실패/ID 미설정/R6는 full-body procedural fallback을 사용한다. fallback 사용 여부와 오류를 기록하고 actual track이 성공했다는 이유 없이 PASS를 선언하지 않는다.
5. R15 기본 Animate script와 공격 track 우선순위(Action), default idle/walk 복귀, 장비 attach·respawn, reject 시 cancel, travel/death 시 cancel을 확인한다.

## Combat 검증

- Basic1 오른쪽→왼쪽, Basic2 왼쪽→오른쪽, Basic3 강한 내려찍기. Windup/Window/Recovery는 각각 `.12/.16/.14`, `.14/.16/.16`, `.20/.20/.20`이다.
- Heavy `.42/.20/.38`: 큰 windup, 양팔 cleaver lift, 하체 체중 이동, 강한 내려찍기. Cleaver가 실제 모델을 통과할 때 서버 hit window가 열린다.
- Input 직후 predicted presentation을 확인한다. Studio network simulation에서 0/100/250 ms latency를 비교하고 승인 phase correction, 거부/timeout/늦은 reply·서버 Busy 조건을 확인한다. client damage나 local dodge 이동을 추가하지 않는다.
- Dodge는 10 studs / .24 s / cooldown 1.4 s. stamina·기본 i-frame 없음. 벽/바닥/맵 가장자리에서 서버 이동이 점진적으로 진행되는지 확인한다.
- BodyHP 140 / HornHP 80. Body-only hit는 HornHP를 줄이지 않는다. Horn heavy의 PartPower 55로 두 번 정확히 맞혀 break, Stagger, HornCore personal reward와 horn variant 교체를 확인한다.
- Idle / Walk / Run / Headbutt / ChargeTelegraph / Charge / Recovery / Hit / HornBreak / Death를 각각 확인한다. Charge는 1.25 s telegraph와 locked facing을 거친다. 충돌한 actor당 한 번 damage가 적용돼야 한다.
- Death pose→personal Loot cosmetic→Inventory 표시→cleanup. 서버 보상 commit은 cosmetic delay와 독립적이다. 동일 attack/receipt replay와 disconnect/rejoin으로 중복 보상이 생기지 않아야 한다.
- 2 clients가 같은 boar를 공격하고 각자의 contribution 기반 재료 지급, 재료/Materials 분류, MarbledLoin rare notice, outbox retry를 확인한다.

## 1 / 5 / 10 / 25 / 50 load / mobile

EDIT Command Bar에서 `workspace:SetAttribute("MonCookQASpawnCount", N)`을 설정한 후 Play한다. 허용 N은 1/5/10/25/50이다. 이 설정은 Studio에서만 적용되며 production 기본 2마리는 바뀌지 않는다. 각 run을 Stop한 후 다음 N을 설정한다.

각 scenario를 warm-up 30초 후 60초 이상 측정한다. 같은 camera route/graphics quality를 유지하며 실기기 모바일과 Studio mobile emulation 결과를 구분한다.

| N | Spawn / gameplay | FPS | client frame P50/P95 | server frame | physics / AI / animation / render | network / memory |
|---|---|---|---|---|---|---|
| 1 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 |
| 5 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 |
| 10 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 |
| 25 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 |
| 50 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 | 미검증 |

Studio Stats/MicroProfiler에서 결과를 capture한다. camera 20/40 studs에서 보어/어깨/뿔 인식, 45/90/150 studs에서 presentation LOD 전환(near 매 frame / medium 20 Hz / far 8 Hz / very far 2 Hz), streaming out/in 및 horn break/death가 즉시 갱신되는지 확인한다. 512 RGBA atlas의 base level 추정은 1 MiB이며 실제 GPU texture compression/mipmap/device memory는 측정값으로 교체한다.

순수 Luau AI 200 ticks의 host benchmark는 렌더/physics/network/player load 없는 코드 경로 측정이다. 모바일/Studio FPS PASS 근거로 사용하지 않는다.

## 실행 경로에서 확인한 제한

DCC-CUA 1.9.3 host는 복구해 ping을 확인했다. QA Studio PID 41052 / HWND 2363256은 `visible=false`였으며 snapshot/restore는 `target_unavailable`을 반환했다. RunScript smoke의 결과 파일은 생성되지 않아 script 실행을 검증할 수 없었다. 공개 API dump는 성공했다. ImportSession/FBX upload API는 RobloxScriptSecurity로 표시돼 일반 Command Bar script로 우회하지 않았다. 실제 GUI import/upload/AnimationTrack/Play/FPS 검증은 남아 있다.

최종 승인 후에만 Phase 2로 진행한다. Cloud는 push된 source/보고서를 review/test할 수 있지만 로컬 Blender/Tripo/localhost endpoint에는 접근할 수 없다.
