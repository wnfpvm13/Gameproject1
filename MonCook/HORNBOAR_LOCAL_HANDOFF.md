# Hornboar Phase 1 로컬 handoff

## 현재 전달 상태 — 2026-10-08 KST

Branch `integration/hunting`, 시작 SHA `5fcb8a93d7e9d294a69425b9c54c9016ae74a008`, 환경 milestone `5eb1768`, 재개 기준 사용자 commit `092ff1c32c6d528bbabfaca86031952671700d4d`를 보존했다. 전달 SHA는 `git log -1 --format=%H -- MonCook/HORNBOAR_LOCAL_HANDOFF.md`로 확인한다. 판정은 **CONDITIONAL PASS**이며 운영 출시 승인은 아니다. Phase 2는 진행하지 않았다.

### Environment

Windows 로컬, Tripo CLI 0.5.1 / 작업 사용량 175 credits / 마지막 확인 잔액 325, frozen 0. Blender 5.2.2 LTS / 기존 adapter 0.2.14를 복구했으며 오래된 catalog 0.1.43으로 downgrade하지 않았다. DCC-MCP CLI 0.20.41, DCC-CUA 1.9.3, Codex CLI 0.160.1, Luau 0.741, Rojo 7.7.1. 실제 FPS 검증은 Studio 0.741.19.7411056; 이후 공식 자동 업데이트로 0.742.0.7421053이 설치됐고 게시된 Basic1은 이 버전에서도 재생했다.

### V1 / V2

| 항목 | V1 | V2 |
|---|---|---|
| Triangles | 1,500 | 2,966 |
| Mesh / material | 14 / 12 | 5 / 2 |
| Texture | 0 | 512×512 atlas 1장 |
| Rig | 14 bones, 다수 분리 mesh | 14 semantic bones, 최대 4 skin influences |

Tripo C1 2,678 / C2 2,633 / C3 2,822 triangles를 비교해 horn·엄니·어깨 및 quadruped rig 적합성이 높은 C3를 선택했다. 산출물은 `art/generated/Monsters/Hornboar/V2/`. 최종 `.blend`는 rest pose와 10 baked actions를 보존한다. 최종 palette로 10 pose / 4방향 preview를 다시 렌더했다. 분리 seam의 boundary/nonmanifold edges는 남으며 내부 교차 표면의 부재를 주장하지 않는다. 최대 단일 파일 약 6.05 MB, 외부 asset storage/LFS 미도입. 기존 V1·기존 테스트 81개 파일의 Git content hash는 시작 SHA와 일치한다.

### Runtime

`art/runtime/Monsters/MON_Hornboar_V2.rbxmx`에 실제 uploaded MeshIds와 opaque skin/shared-string data를 포함했다. Rojo build 후 새 Studio 파일에서 5 MeshParts / 14 Bones / 준비 marker / RootPart identity / scale 1을 확인했다. 실제 MeshIds·creator·hash는 `metadata/roblox_uploads.json`에 있다.

**Studio import는 `export/MON_Hornboar_V2_Studio.fbx`를 사용한다.** 실제 발견한 canonical FBX의 100× scale 및 Head mesh/Bone 이름 충돌을 HeadVisual 이름·scale 0.01·forward 보정으로 교정했다. TextureId `rbxassetid://109860201891046`. FBX sidecar의 stale 2K JPEG 및 GLB의 오래된 palette를 수정해, 두 FBX embedded/sidecar와 GLB embedded 이미지가 최종 512 PNG bytes와 정확히 일치한다. Visual CanCollide/CanTouch/CanQuery false, 서버 Body/Horn hitboxes 유지.

### Animation / Combat

Hornboar Idle / Walk / Run / Headbutt / ChargeTelegraph / Charge / Recovery / Hit / HornBreak / Death 구현, baked FBX·samples·pose renders 보존. 실제 AI state 변화·공격·뿔 교체 확인. 전체 시각 acceptance, foot sliding, contact 및 streaming은 남아 있다.

Player Basic1/2/3 / Heavy / Dodge **5개 모두 실제 운영용 Animation asset으로 게시**됐다. 각 ID는 `102113588927000` / `80795014037306` / `98088572362685` / `130446557294676` / `131747758996934`다. 모두 type 24 / User creator 소유를 확인했다. Studio 0.742 실제 Play에서 direct Animator 재생뿐 아니라 native ButtonR2 combo → Q Heavy → F Dodge 입력을 통한 HuntingInputController/prediction/server approval 경로의 재생도 확인했다. 각 Length .42 / .46 / .60 / 1.00 / .24 s, Playing=true, Action priority. Config에는 임시 hash가 아닌 위 ID를 연결했다. 기본 procedural fallback은 유지한다.

Local prediction → server approval/correction/rejection, server damage authority 및 Dodge 10 studs/.24 s, stamina/i-frame 정책을 유지했다. 리뷰에서 찾은 observer published-track 중복 생성은 `CombatTrackOwnership`과 `CombatTrackPlayer`에서 수정했다. Engine-replicated track은 읽기만 하며 Load/Play/seek/Stop/Destroy하지 않는다. 실제 2-client 확인은 남아 있다.

실제 Play: BodyHP 140 / HornHP 80 → BodyHP 32 / HornHP 0, HornBroken=true; intact transparency 1 / broken 0 / horn query false. HornCore 1개, 실제 강공 처치 후 Dead personal Loot event, 고기 5→7, 원래 encounter 제거를 확인했다. 이는 Studio fake transport의 단일 플레이어 검증이며 production persistence / 2-client contribution을 대신하지 않는다.

### Performance

Core Ultra 7 256V / Arc 140V / 약 16 GB RAM PC, Galaxy A06 가로 preset(800×360, resolution scale 2). 각 run은 30 s warmup + 60 s 측정, near/medium/far camera 각 20 s다.

| N | Client FPS | Client P95 ms | Server Heartbeat P95 ms |
|---|---:|---:|---:|
| 1 | 59.95 | 19.18 | 18.91 |
| 5 | 59.27 | 18.67 | 18.67 |
| 10 | 59.92 | 18.87 | 18.94 |
| 25 | 59.92 | 19.11 | 18.93 |
| 50 | 59.87 | 19.82 | 19.07 |

50마리에서 실제 250 MeshParts / 700 Bones 확인. **실기기 모바일 FPS 미검증**: preset은 PC CPU/GPU로 실행된다. Heartbeat dt는 server CPU 작업 시간이 아니며 memory는 Studio 환경을 포함한다. 5마리의 단일 743.53 ms stall 원인은 미검증이다. 초기 1/5 network sampler는 Stats 이름 불일치로 미수집; 5 별도 snapshot과 10/25/50 samples는 보존했다. MicroProfiler snapshot 요청 중 Studio session이 종료돼 physics/AI/animation/render 분해 결과는 미확보다.

실제 receipt 및 mobile screenshot / 5개 publication screenshot: `docs/qa/2026-10-08/studio_performance.json`, `studio_runtime.json`, `published_animations.json`.

### Tests / 남은 작업 / Cloud

전체 syntax/type/regressions: 89 files, 27 suites / 351 groups PASS. Texture regression 2 tests PASS. Fresh FBX readback: 2,966 triangles / 5 meshes / 14 bones / 2 materials / 512 texture. V2 validator는 GLB topology/skin/atlas, 5 clips, runtime opaque refs/skin/physics flags, 기존 81개 파일 보존을 통과했다. Rojo build 및 Studio template readback 확인.

남음: 2-client replication/contribution, 0/100/250 ms latency, 실제 모바일·profiler 및 전체 시각 acceptance. 5개 animation 게시/ID 연결은 완료했다. 절차: `HORNBOAR_STUDIO_QA.md`. Cloud는 push된 SHA 기준 read-only review/test만 수행하며 아래 writer 소유권을 유지한다. main merge / Phase 2는 사용자 승인 이후에만 가능하다.

## Archive: Milestone 1 — 아래 내용은 2026-10-07 당시 기록

날짜: 2026-10-07 KST. 로컬 Windows checkout: `Documents/Rob/Gameproject1`.
브랜치: `integration/hunting`. 시작 SHA: `5fcb8a93d7e9d294a69425b9c54c9016ae74a008`.

## Milestone 1: 환경 / Repo / V1 분석

- Tripo CLI 0.5.1, 인증/API 연결 정상. 시작 balance 500, frozen 1000.
- DCC-MCP CLI 0.20.41, Blender 5.2.2 LTS, instance `2bee13a1-083b-41eb-986f-4060d9cb4bec`, loopback port 56852.
- 기본 `Scene`의 Camera/Cube/Light는 보존했다. 별도 `MonCook_V1_Audit` Scene에서 임시 object의 transform read/write 후 제거를 검증했다.
- Codex CLI 0.160.1. 원격 시작 SHA와 로컬 시작 SHA가 일치하며 원래 checkout의 작업을 수정하지 않았다.
- V1 실제 FBX: 1500 triangles / 14 meshes / 12 materials / 0 textures / 14 bones. 모든 meshes에서 duplicate vertex/face, zero-area face, boundary/nonmanifold edge count 0. 서로 교차하거나 내부에 겹친 별도 표면의 부재까지 증명하는 검사는 아니다.
- 결과: `art/generated/Monsters/Hornboar/V2/metadata/v1_analysis.json`, `blender/V1_reference.blend`, `preview/v1_{front,left,back,three_quarter}.png`.
- V1 render에서 멧돼지·뿔·엄니·등판을 확인했다. V1을 삭제하거나 덮어쓰지 않았다.
- 기존 Luau 전체: 79개 파일 syntax, 순수 module 타입 분석, 23 suites / 324 groups PASS (공식 Luau 0.741).
- 기존 서버 전투/AI/Horn break/개인 Loot/Inventory 경로를 유지한다. 기존 플레이어 animation은 서버 ActionResult 이후 procedural upper-body pose를 시작한다.
- 실제 Studio-imported `MON_Hornboar_V1.rbxm`이 저장소에 없고, 현재 `.rbxmx`는 MeshPart 없는 옛 skeleton 템플릿이다. Studio runtime 실행 / 모바일 FPS / uploaded animation은 미검증이다.

## 로컬 writer 소유권

로컬 art 및 animation 작업 진행 중이다. Cloud는 이 branch의 **push된 commit 기준 read-only review/test**만 수행한다. 다음 파일을 동시에 수정하지 않는다:

- `art/generated/Monsters/Hornboar/V2/**`
- `tools/hornboar_v2_blender.py`
- `HuntingAnimator`, `CombatAnimation`, `HuntingAssetBinder`, `ImportedHornboarRig`
- combat timing / player animation 관련 파일

Git가 source of truth다. Cloud는 로컬 Blender, Tripo CLI, localhost MCP를 사용할 수 없다. 로컬 작업 재개 전 `git fetch`와 `git status`로 remote 차이를 확인한다.
handoff를 포함하는 정확한 milestone SHA는 이 문서 경로에 대한 `git log -1 --format=%H -- MonCook/HORNBOAR_LOCAL_HANDOFF.md`로 확인한다.
