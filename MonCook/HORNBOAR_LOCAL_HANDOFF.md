# Hornboar 로컬 작업 handoff

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
