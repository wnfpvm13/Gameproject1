# Hornboar V2 후보

실제 Tripo 후보 3개 → 후보 C3 quadruped rig → Blender 후처리. **2,966 triangles / 5 meshes / 14 bones / 2 materials / 512 atlas 1장**.

- `source/`: 원본 후보 3개, Tripo 생성 task/seed 기록, rig source. 원본을 수정하지 않았다.
- `blender/MON_Hornboar_V2.blend`: 최종 mesh/skin 및 10개 baked actions. V1 reference blend는 별도다.
- `export/MON_Hornboar_V2.fbx`: Studio import용, embedded diffuse atlas, 14 bones, 5 meshes.
- `export/MON_Hornboar_V2.glb`: 실제 검증한 compact mesh/skin. 다른 분석 Scene을 제외했다.
- `export/animations/*.fbx`: Idle / Walk / Run / Headbutt / ChargeTelegraph / Charge / Recovery / Hit / HornBreak / Death.
- `preview/`: Blender 4방향 beauty/wire, 실제 viewport, pose renders. **Studio screenshot은 아니다.**
- `metadata/`: 측정, source task, source clip samples, export hash, validation 결과.

정상 Horn_Intact 표시 / Horn_Broken 숨김. 파괴 시 Transparency를 반대로 바꾸며 서버 HornHitbox의 query를 끈다. visual mesh는 physics/hit detection에 쓰지 않는다.

소스 좌표: Blender +Y forward, +Z up → Roblox -Z forward, +Y up. 전체 길이 약 11.68 / 높이 5.87 / 폭 5.60 studs, ground Z=0. Studio importer에서 자동 resize를 적용하지 말고 이 치수를 확인한다.

소스 seam 분할에 따른 boundary edges와 일부 Tripo nonmanifold junctions가 기록돼 있다. 중복 vertex/face·영면적 face·무가중 vertex는 0이며 export와 skin 검증을 통과했지만, 모든 내부 교차 표면이 없다고 선언하지 않는다. 실제 Studio 변형/streaming/거리 silhouette 검증은 남아 있다.

최대 단일 파일은 약 6.35 MB로 GitHub 일반 Git 단일 파일 제한 아래다. 현재 repository에는 LFS 정책이 없으며 새 외부 asset storage를 도입하지 않았다.

**Roblox publication / 실제 runtime `.rbxm` / mobile FPS 미검증.** 파일 생성만으로 Phase 1 완료를 선언하지 않는다. `HORNBOAR_STUDIO_QA.md`와 `tools/InstallHornboarV2.studio.luau`를 따른다.
