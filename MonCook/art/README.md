# Phase 1 corrected Hornboar assets

Current Hornboar replaces the rejected sphere/Part prototype with an authored Blender mesh: **4,248 triangles, 14 bones, 13 source actions**. It is a **V1 candidate awaiting Studio acceptance**. Other 15 source assets remain V1. The table below keeps the complete asset inventory; the previous native-equivalent description applies only to those other assets.

The Hornboar runtime template is an invisible authoritative rig/hitbox skeleton. The QA place embeds actual Blender vertices/triangles/palette in `Shared.Assets.HornboarMeshData`. `HornboarMeshVisual` creates 14 real EditableMesh-backed MeshParts per encounter from one cached template set per client, and binds them to Motor6Ds. These are the source topology, not sphere equivalents. Studio API execution and published activation/permissions/memory are **unverified**; failure reports QA blocked and does not restore the rejected prototype. Imported owned MeshParts may replace this path while preserving the binding/rig contract. See [CORRECTION_QA](../CORRECTION_QA.md).

Source artifacts: `blender/Hornboar/MON_Hornboar_V1.blend`, FBX/GLB, `hornboar_mesh.json`, measured manifests, actual FBX reimport record and Close/Medium/Far/AvatarScale renders. The source hash and nondegenerate face/index/palette/bounds checks tie the packet to the real blend. Custom body/horn/heavy WAVs are in `audio/`, while runtime currently uses a short builtin sample with distinct pitch/volume; authored audio upload is pending.

Corrected workflow from MonCook/:

```sh
blender --background --python art/blender/build_assets.py
python3 art/export_hornboar_mesh.py
python3 art/export_runtime.py
blender --background --python art/blender/validate_exports.py
blender --background --python art/blender/render_correction_qa.py
rojo build default.project.json -o MonCook_Phase_1_Correction.rbxlx
python3 tools/validate_hunting_artifacts.py --place MonCook_Phase_1_Correction.rbxlx
```

For Hornboar-only iteration use `redesign_hornboar.py` before the packet export instead of regenerating the other assets. `build_assets.py` always calls the redesigned mesh builder and cannot regenerate the rejected primitive Hornboar. Source actions: Idle, Walk, Run, Alert, ChargeWindup, Charge, Headbutt, LightHit, HeavyHit, HornHit, HornBreak, Stagger, Death. Runtime animation is server-time-driven Motor6D poses, with four upper legs and four shins; uploaded source AnimationTrack playback is pending.

| Asset ID | Status | Source triangles | Runtime BaseParts |
| --- | --- | ---: | ---: |
| MON_Hornboar_V1 | Redesigned V1 candidate | 4,248 | 14 server rig nodes + 2 hitboxes; 14 client MeshParts |
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

The remaining 15 models use the original native Part/WedgePart equivalents and have not been reclassified as imported Blender meshes. Source triangle counts and runtime parts/EditableMesh memory are different budgets. No asset is Final.

Art TODO: actual Studio silhouette/rig/hitbox acceptance, R6/R15 full-body poses, small/large window and mobile memory/streaming checks, owned mesh/animation upload if chosen, and final audio IDs. Source renders are not Studio screenshots.
