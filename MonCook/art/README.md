# Phase 1 corrected Hornboar assets

Current Hornboar replaces the rejected sphere/Part prototype with an authored Blender mesh: **1,500 triangles, 14 bones, 13 source actions**. It is a **V1 candidate awaiting Studio acceptance**. Other 15 source assets remain V1. The table below keeps the complete asset inventory; the previous native-equivalent description applies only to those other assets.

Latest lightweight report and import guide: [HORNBOAR_LITE.md](../HORNBOAR_LITE.md). Recommended Studio Rigid FBX: **92,492 bytes / 14 compatible named meshes**. Optional skinned FBX: **125,868 bytes / 3 meshes / 14 bones**. Animated FBX preserves 13 actions. Geometry is 1,500 triangles / 838 vertices; authoring JSON is 39,932 bytes. The latest user request overrides the previous target with 1,000–2,000 triangles.

The game now uses the user's Studio-imported MeshPart/Motor6D asset directly. Runtime EditableMesh generation and its Luau packet were removed in the newer shared branch and remain removed. Lightweight source/export files do not automatically replace uploaded MeshIds. The 3-mesh skinned import needs separate animation integration to replace the existing rigid Motor6D model.

The original imported .rbxm recorded in imported_hornboar.json is absent from the repository; full place validation is blocked until it is restored. The full ZIP contains source/export files, not a newly validated play file. Original asset size/hash checks remain strict.

Source artifacts: `blender/Hornboar/MON_Hornboar_V1.blend`, FBX/GLB, `hornboar_mesh.json`, measured manifests, actual FBX reimport record and Close/Medium/Far/AvatarScale renders. The source hash and nondegenerate face/index/palette/bounds checks tie authoring geometry to the real blend. Custom body/horn/heavy WAVs are in `audio/`, while runtime currently uses a short builtin sample with distinct pitch/volume; authored audio upload is pending.

Corrected workflow from MonCook/:

```sh
blender --background --python art/blender/build_assets.py
python3 art/export_hornboar_mesh.py
python3 art/export_runtime.py
blender --background --python art/blender/validate_exports.py
blender --background --python art/blender/render_correction_qa.py
# Restore imported .rbxm and remove conflicting old skeleton .rbxmx before Rojo build.
python3 tools/validate_hunting_artifacts.py --art-only
```

For Hornboar-only iteration use `redesign_hornboar.py` before authoring topology validation instead of regenerating the other assets. `build_assets.py` always calls the redesigned mesh builder and cannot regenerate the rejected primitive Hornboar. Source actions: Idle, Walk, Run, Alert, ChargeWindup, Charge, Headbutt, LightHit, HeavyHit, HornHit, HornBreak, Stagger, Death. Runtime animation is server-time-driven Motor6D poses, with four upper legs and four shins; uploaded source AnimationTrack playback is pending.

| Asset ID | Status | Source triangles | Runtime BaseParts |
| --- | --- | ---: | ---: |
| MON_Hornboar_V1 | Redesigned V1 candidate | 1,500 | source: 14 mesh groups; imported game asset kept; 2 server hitboxes |
| WPN_StarterCleaver_V1 | V1 | 2,168 | 22 |
| ING_HornboarMeat_V1 | V1 | 504 | 4 |
| ING_ArcaneFat_V1 | V1 | 504 | 4 |
| ING_MarbledLoin_V1 | V1 | 1,044 | 9 |
| MAT_HornCore_V1 | V1 | 240 | 7 |
| ENV_Greenwood_Tree_A_V1 | V1 | 328 | 5 |
| ENV_Greenwood_Tree_B_V1 | V1 | 328 | 5 |
| ENV_Greenwood_Tree_C_V1 | V1 | 328 | 5 |
| ENV_Greenwood_Rock_A_V1 | V1 | 80 | 2 |
| ENV_Greenwood_Rock_B_V1 | V1 | 80 | 2 |
| ENV_Greenwood_Rock_C_V1 | V1 | 80 | 2 |
| ENV_Greenwood_Bush_V1 | V1 | 300 | 4 |
| ENV_Greenwood_Grass_V1 | V1 | 72 | 10 |
| ENV_Greenwood_Stump_V1 | V1 | 72 | 3 |
| ENV_Greenwood_Sign_V1 | V1 | 224 | 4 |

The remaining 15 models use the original native Part/WedgePart equivalents. Source triangle counts, uploaded geometry, serialized .rbxm size and actual device memory are distinct measurements. No asset is Final.

Art TODO: actual Studio silhouette/rig/hitbox acceptance, R6/R15 full-body poses, small/large window and mobile memory/streaming checks, owned mesh/animation upload if chosen, and final audio IDs. Source renders are not Studio screenshots.
