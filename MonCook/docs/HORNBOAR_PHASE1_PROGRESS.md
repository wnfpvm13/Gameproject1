# Phase 1 진행 기록

Plan/spec: 사용자가 제공한 Phase 1 Hornboar + Player Combat 요청, Milestone 1–10.
재개 기준: 2026-10-08 KST, `092ff1c32c6d528bbabfaca86031952671700d4d` (사용자 commit, 원격과 동일).

- [x] Milestone 1: 환경 / V1 분석, `5eb1768`, baseline 324 groups.
- [x] Milestone 2–4 source: Tripo 후보 3개 → C3, 14-bone Blender rig, 10 baked actions, 2966 triangles.
- [x] Milestone 5–6 code/source: R15 clip 5개, local prediction/rejection, skinned bone binding, LOD 및 기존 authority/loot 유지. 실제 playback 검증은 진행 중.
- [x] Offline regressions: 직전 run 346 groups, 현재 재개 후 fresh run 예정.
- [x] Studio import: scale 100×와 Head mesh/Bone 충돌을 실제 측정한 뒤 Studio 전용 FBX로 교정. 실제 5 MeshParts / 14 Bones 및 MeshIds 발급.
- [x] Studio runtime template 설치 / normal horn visibility / visual collision separation 확인.
- [x] 실제 runtime XML 편입, Rojo build 및 Studio 5 meshes / 14 bones readback.
- [x] Player 5 temporary AnimationTrack 실제 재생, Basic1 실제 게시(type 24) 및 0.742 Play에서 .42 s track 확인.
- [x] Player 5개 운영용 ID 모두 게시·연결·type 24/creator 확인 및 실제 입력 AnimationTrack 재생. API 미지원과 DCC-CUA popup 오류는 사용자 전면화/양식 열기 도움으로 해결.
- [x] 단일 플레이어 실제 AI / horn break / Dead reward / 고기 5→7 / HornCore 1 / 원래 encounter cleanup.
- [x] 1 / 5 / 10 / 25 / 50 Galaxy A06 Studio emulation FPS 수집, 30 s warmup + 60 s sample.
- [ ] Profiler 분해 / 물리 모바일 / 2-client / 전체 animation visual acceptance.
- [x] Final tests와 handoff 갱신. 검증된 milestone은 아래 commit 기록으로 전달한다.

Ruling: 이미 사용자 commit에 들어간 이전 산출물과 테스트는 재작성/삭제하지 않는다 — 기존 작업 보존과 현재 user spec이 우선하며, 이후 수정은 재현/검증을 거친다. 틀렸을 경우 기존 결함을 새 regression/Studio QA에서 찾아 수정한다.

Ruling: Studio 메시에 대해서는 실제 저장된 QA XML에서 opaque skin/mesh 데이터까지 함께 복구한다 — 새 가짜 MeshIds/EditableMesh 경로를 만들지 않는다. 틀렸을 경우 Rojo build 및 Studio roundtrip이 실패하므로 그 단계에서 중단한다.

재개 시 발견: `.fbm/Hornboar_BaseColor_512.png`는 실제 JPEG header이며, 원본 packed data가 export된 흔적이다. 외부 atlas는 실제 512 PNG다. asset memory 검증 전에 texture export/readback regression으로 확인/수정한다.

수정/검증: FBX embedded/sidecar 및 GLB embedded PNG가 최종 512 atlas와 정확히 일치한다. GLB의 decoded pixels가 오래된 palette를 유지하는 것도 재현해 image.reload 후 교정했다. Texture 2 tests PASS. 최종 10 pose/4 views 갱신, fresh FBX 2966/5/14 readback, V2 offline validator 및 기존 81개 파일 보존 확인.

Code review의 observer published AnimationTrack 중복 재생을 수정했다. 소유자만 published track을 만들고 관찰자는 engine replication을 읽는다. 새 회귀 5 groups를 포함한 전체 89 files / 27 suites / 351 groups PASS.

2026-10-08 재개: 종료된 Studio는 공식 0.742 자동 업데이트 후 연결을 복구했다. Blender는 설치된 0.2.14 확장을 재활성화해 복구했으며 catalog의 오래된 0.1.43을 설치하지 않았다. 현재 증거와 미검증 항목은 HORNBOAR_LOCAL_HANDOFF.md 및 docs/qa/2026-10-08/에 저장했다.

Git milestone: `1294dcd` art/runtime/atlas (원격 push 확인), `e3b7650` observer track 소유권 수정, `f82d1b9` 5개 운영용 ID 연결. 최종 QA/handoff commit SHA는 `git log -1 --format=%H -- MonCook/HORNBOAR_LOCAL_HANDOFF.md`로 찾는다.

5개 asset 모두 actual Animation type 24 / User creator 소유, 0.742의 direct Animator 및 실제 ButtonR2 combo/Q/F 입력 경로에서 Playing=true / .42/.46/.60/1/.24 s를 확인했다. 마지막 게임 console은 MonCook ready 메시지만 있으며 게임 오류가 없었다. 실제 모바일/2-client/profiler/전체 시각 acceptance는 계속 미검증이다.

로컬 writer가 계속 작업 중이다. Cloud는 push된 commit 기반 read-only review/test만 수행한다. Phase 2는 진행하지 않는다.
