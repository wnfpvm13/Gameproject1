# Hornboar Studio 경량화 — 2026-10-07

## 1. 구현 내용

최신 요청에 따라 내부 triangle 목표를 3,000–6,000에서 **1,000–2,000**으로 낮췄습니다. 단면 사이 불필요한 분할과 작은 bevel을 줄이면서 긴 몸통·큰 어깨·작은 머리·큰 전방 뿔·Upper/Lower/Hoof 네 다리와 14개 뼈를 유지했습니다. Blender source mesh objects는 44→14입니다.

| 항목 | 이전 | 경량화 후 |
| --- | ---: | ---: |
| Triangles | 4,248 | **1,500** (64.7% 감소) |
| Source vertices | 2,212 | **838** (62.1% 감소) |
| 제작용 topology JSON | 121,662 bytes | **39,932 bytes** (67.2% 감소) |
| GLB | 570,820 bytes | **217,184 bytes** |
| 13개 action 포함 FBX | 1,815,692 bytes | **1,254,140 bytes** |
| Studio Motor6D용 개별 메시 FBX | 이전 FBX 사용 | **92,492 bytes**, 14 named meshes |
| Studio skinned FBX | 별도 없음 | **125,868 bytes**, 3 skinned meshes |

권장 `Studio_Rigid.fbx`는 skeleton/baked animation을 제외하고 기존 Motor6D용 part 이름의 14개 mesh만 내보냅니다. RootPart/Motor6D는 기존 Studio rig에서 유지합니다. 선택 가능한 작은 skinned FBX는 Body·HornIntact·HornBroken 3 meshes로 합쳤습니다. 14 bones와 head/leg deform weights를 보존합니다. 13 actions는 `.blend`와 제작용 FBX에 그대로 있습니다.

## 2. 변경 파일 / Studio 가져오기

- **`art/exports/Monsters/MON_Hornboar_V1_Studio_Rigid.fbx`**: 권장 14개 개별 메시, 90KB.
- `art/exports/Monsters/MON_Hornboar_V1_Studio.fbx`: 선택 가능한 3-mesh / 14-bone skinned 가져오기용.
- `art/exports/Monsters/MON_Hornboar_V1.fbx`, `.glb`, `.blend`: 경량 geometry와 13개 source action.
- `art/blender/redesign_hornboar.py`, `build_assets.py`, `export_hornboar_rigid.py`, `validate_exports.py`, `export_hornboar_mesh.py`, `export_runtime.py`: 재현 pipeline·export 검증. 제거된 runtime mesh loader를 다시 만들지 않습니다.
- `art/hornboar_mesh.json`, optimization/asset/export manifests, previews, artifact validator와 보고/QA.

Studio에서 기존 게임 리그에 맞춰 가져올 때:

1. **3D Importer**에서 `MON_Hornboar_V1_Studio_Rigid.fbx`를 별도 Model로 가져옵니다. Torso/Head/4 upper legs/4 lower shins/NeckMass/Horn_Intact/Horn_Broken/Tail 14 meshes를 확인합니다.
2. 뿔 포함 길이 약 11.8 studs, 높이 약 5.6 studs, 폭 약 5 studs로 scale을 확인합니다.
3. 기존 RootPart/Motor6D/AnimationController를 보존한 채 같은 이름의 mesh를 연결합니다. 기존 Part 인스턴스를 유지해 `ApplyMesh`로 형상만 교체하거나, 새 Part를 연결할 때 Motor6D Part0/Part1과 rest transform을 유지합니다. NeckMass는 기존 목/몸통에 붙입니다. 이 연결은 실제 Studio QA가 필요합니다.
4. Horn_Broken은 초기 Transparency=1, Horn_Intact는 0이며, 파괴 시 반대로 바뀝니다. Visual mesh의 CanCollide/CanTouch/CanQuery는 false입니다.
5. source clip 편집에는 `.blend` 또는 13-action FBX를 사용합니다. 가져오기 전용 두 FBX에는 동작 clip이 없습니다.

현재 공유 브랜치의 게임은 **사용자가 Studio에서 가져온 MeshPart + Motor6D rig**를 직접 사용합니다. 최신 ImportedHornboarRig/Binder/Animator 구조와 runtime mesh 생성 제거를 그대로 유지했습니다. 이번 경량 source가 그 imported asset의 uploaded MeshId를 자동 변경하지는 않습니다.

3-mesh FBX는 **skinned Bones** 표현이므로 현재 Motor6D rig에 이름만 바꿔 덮어쓸 수 없습니다. 모델을 독립적으로 가져와 사용할 수 있으며, 기존 게임에 교체하려면 별도 rig 연결과 부위 파괴 QA가 필요합니다. 원래 imported MeshParts를 보존한 상태에서 경량 FBX를 먼저 별도 Model로 테스트합니다. 임의 mesh/AnimationId 업로드는 수행하지 않았습니다.

## 3. 테스트 결과

- 최신 imported-rig 회귀 8개를 포함해 **324개 테스트 그룹**, **79개 Luau 구문 검사**, 순수 모듈 strict 분석 PASS.
- 실제 16개 FBX 재가져오기 PASS; Hornboar 1,500 triangles / 14 bones / 13 actions 보존.
- 두 Studio FBX 재가져오기 PASS: rigid 14개 compatible part 이름 / 1,500 triangles / no skeleton·clips, skinned 3 meshes / 14 bones / deform weights / no clips.
- Art-only 검사 PASS: 정확한 source SHA·triangle index/면적·palette·Body/Horn bounds·triangle/vertex/size budget. 게임 소스에 runtime EditableMesh 경로가 없는 검사도 유지합니다.
- Close/Medium/Far/AvatarScale Blender renders를 새로 만들고 이전 silhouette와 비교했습니다. Studio 화면이 아닙니다.

## 4. 실패 / 미검증 항목

실제 Studio import·표시·모바일 메모리·uploaded mesh 교체는 미검증입니다. source 파일 크기와 실제 기기 메모리는 다릅니다.

**새 플레이 파일 검증은 보류했습니다.** 최신 원격 브랜치가 요구하는 `art/runtime/Monsters/MON_Hornboar_V1.rbxm`은 저장소에 없습니다. 이전 transfer staging의 일부 base64도 원본 전체가 아니므로 복원하지 않았습니다. validator의 정확한 원본 크기/SHA 검사는 유지하며, 이를 우회해 플레이 성공으로 보고하지 않습니다. 전체 ZIP은 source/export 묶음이며 새 acceptance 완료 `.rbxlx`를 포함하지 않습니다.

## 5. TODO

- 원본 Studio `.rbxm`(76,575 bytes, SHA-256 `df3ef039ba0141c7227cdd560dd64ecd1f59341ed0ba50a3695691f9a4782578`)을 runtime 경로에 넣어 기존 imported asset을 복구합니다. `.gitignore`에는 runtime `.rbxm` 예외를 추가했습니다. 같은 asset 이름의 이전 skeleton `.rbxmx`와 동시에 넣지 않습니다.
- 경량 FBX의 실제 Studio import/scale/material, rig 연결, Horn hide/show, 2–4인 streaming/respawn, 모바일 메모리를 확인합니다.
- 기존 server Body/Horn hitbox와 모든 attack/part-break/loot 회귀를 확인하고 Phase 1 acceptance를 판단합니다.

## 6. 다른 브랜치 영향

integration/hunting의 MonCook 아트/검증/문서만 변경했습니다. 최신 ImportedHornboarRig/Binder/Animator와 CombatService/MonsterService/Body-Horn Config/server damage/contribution/Personal Loot/Core 1회/death receipt/Inventory/Party/Expedition 계약은 그대로입니다. main과 다른 게임은 수정하지 않으며 Phase 2는 시작하지 않습니다.
