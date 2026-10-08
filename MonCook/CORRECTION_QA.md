# Phase 1 Correction Studio QA — 실행 결과 미검증

이번 파일: `MonCook_Phase_1_Correction.rbxlx`. 기존 사냥/보상 검증은 [HUNTING_QA.md](HUNTING_QA.md)를 함께 따릅니다. 자동 324개 테스트와 FBX 재가져오기/빌드 검증은 실제 Studio acceptance를 대신하지 않습니다.

최신 [경량화 보고](HORNBOAR_LITE.md)의 권장 rigid FBX는 1,500 triangles / 14 named meshes / 92,492 bytes이며, 선택 가능한 skinned FBX는 14 bones / 125,868 bytes입니다. 제작 source가 imported 게임 모델의 MeshId를 자동 변경하지는 않습니다. 원본 imported `.rbxm`이 저장소에 없어 새 플레이 파일 재빌드는 현재 보류합니다. 사용자 Studio의 기존 모델을 보존하고 FBX를 별도 Model로 먼저 확인합니다.

## 모델 실행 조건

Hornboar는 사용자가 Studio에서 FBX Import 3D로 가져온 `MeshPart + Motor6D + AnimationController` custom rigid rig를 사용합니다. 런타임 `EditableMesh` 생성은 더 이상 사용하지 않습니다. 필수 part는 RootPart/Torso/Head/4 upper legs/4 lower shins/Horn_Intact/Horn_Broken/Tail이며, Binder가 이름을 semantic Root/HornIntact/HornBroken 및 joints로 매핑합니다.

서버 gameplay 판정은 imported mesh 자체가 아니라 별도 invisible Body/Horn hitbox를 사용합니다. imported MeshParts는 collision/query/touch를 끄고 presentation 전용으로 둡니다. Horn break는 `Horn_Intact`를 숨기고 `Horn_Broken`을 표시하며 Horn gameplay query도 즉시 비활성화합니다.

원본 Studio-imported `.rbxm` 계약: 76,575 bytes, SHA-256 `df3ef039ba0141c7227cdd560dd64ecd1f59341ed0ba50a3695691f9a4782578`. 이 해시가 다르면 다른 모델로 간주하고 QA를 보류합니다.

## Setup

- Studio Server & Clients 2명, 이후 4명. R15와 R6 각각 확인합니다. 기본 PC M1/Q/F/I, Touch 3개 버튼, Gamepad R2/X/B.
- 먼저 `Testing.ShowCombatHitboxes = false`에서 모션/실루엣/피드백을 확인합니다.
- 다음 `ReplicatedStorage.Shared.Config.Definitions`의 플래그를 테스트 시작 전에 true로 바꿉니다. 코드 변경 시 Rojo rebuild 또는 serve가 필요합니다. Studio와 해당 flag가 모두 true일 때만 표시됩니다. Published에서는 flag true여도 생성하지 않습니다.
- Body = 파랑, Horn = 보라. Basic = 골드, Heavy = 붉은 주황. 공격 바닥 윤곽은 실제 수평 부채꼴 경계이고, 서버 hit window에 밝아집니다. 수직 허용폭은 HuntingConfig.VerticalTolerance입니다. 점/중심이 아니라 oriented box와 부채꼴의 교차 표면을 확인합니다.
- 최대 공격 거리는 Avatar HumanoidRootPart에서 **hitbox 접촉 표면**까지 잽니다. 몬스터 root/box center까지의 거리와 구분합니다.

## Combat hit readability 12항목

| # | 시도 | 기준 |
| --- | --- | --- |
| 1 | 몸 중앙 Basic | Body spark/sound·짧은 몸 뒤틀림·Body HP 감소 |
| 2 | 어깨 타격 | 박스 중심이 arc 밖이어도 유효 표면 접촉 인정 |
| 3 | 옆구리 타격 | 넓은 몸통 영역을 자연스럽게 타격, 원치 않는 Horn bonus 없음 |
| 4 | 정면 Horn Heavy | Horn spark·head recoil·별도 Horn HP 감소 |
| 5 | 대각선 Horn Heavy | generous box에서 정상 접촉, assist 회전은 작고 제한됨 |
| 6 | Horn 바로 옆 Body | Horn volume 밖이면 Body hit, 둘 다 유효할 때 Horn 우선 |
| 7 | 최대 거리 | Basic 5.8 / Heavy 6.8 studs 표면 경계 접촉 인정 |
| 8 | 그 바깥 | damage·spark·hit sound·contribution 없음 |
| 9 | 약간 옆 전방 대상 | 96° Basic / 108° Heavy fan 안의 표면 접촉 인정; 화면 밖 target에 강제 lock 없음 |
| 10 | 몬스터 반대 방향을 보고 공격 | 뒤쪽 monster root 및 뒤쪽 volume는 hit/assist 없음 |
| 11 | Basic1·2·3 | 오른쪽→왼쪽, 반대/대각선, overhead finish가 torso/arms/weapon으로 구분 |
| 12 | Heavy | 긴 windup·양팔 support·큰 torso weight shift·강한 recoil/short stagger; high PartPower 유지 |

정면/측면으로 반복 접근하면서 명백한 visual 접촉 대부분이 인정되는지 확인합니다. 몬스터가 다가오는 중, 플레이어 이동/점프, 몸/뿔 overlap, 장애물 뒤, 여러 대상, 모바일 가로/세로에서도 반복합니다. 화면상 cleaver의 forward stroke와 damage/feedback 시점을 녹화해서 Config window/pose를 조정합니다. 이 동기화는 오프라인 검사만으로 확정하지 않습니다.

## Animation / art 18항목

1. Basic1 횡베기 — right/left shoulders·waist/root torso twist·cleaver 모두 움직임.
2. Basic2 반대/대각선 베기 — 1과 다른 방향.
3. Basic3 overhead 마무리.
4. Heavy — 더 긴 준비·양팔·상체 무게 이동.
5. Dodge — 몸을 숙이는 lean, positional 이동/cooldown.
6. Windup/Hit/Recover와 서버 window; Client pose가 damage를 결정하지 않음.
7. Close/Medium/Far에서 설명 없이 판타지 멧돼지로 읽힘.
8. 긴 몸통/큰 어깨/낮은 뒷부분/Upper→Lower→Hoof 네 다리.
9. 작은 묵직한 head와 protruding snout.
10. 이마의 굵은 root→휘어지는 전방 큰 Horn, 약한 magic accent.
11. LightHit 짧은 flinch — AI를 과도하게 끊지 않음.
12. HeavyHit 더 큰 body recoil·0.24초 stagger.
13. HornHit 별도 head recoil와 청록 thin spark.
14. HornBreak 큰 head recoil·stagger·VFX.
15. Intact 숨김→짧은 stump, horn query 즉시 false, Core 개인 연출.
16. ChargeWindup 멈춤/낮춘 머리/앞발 준비·바닥 예고.
17. Charge running leg cycle·방향 고정·Recover, 미끄러짐/판정 괴리 확인.
18. Death 옆으로 쓰러짐·밝은 particles/fade 후 despawn, 보상 cosmetic은 death 시작 뒤 표시.

Native R6/R15 Motor6D additive poses는 PreAnimation에서 이전 delta를 제거하고 PreSimulation에서 기본 Avatar Animator 결과 위에 적용합니다. 중첩 축적/리스폰/기본 걷기·점프·Shift Lock·메뉴/Chat와 충돌하지 않는지 확인합니다. Blender FBX의 13개 동작은 source/export이며 uploaded track playback은 아닙니다.

## 보상·피드백·성능 회귀

두 명이 같은 Hornboar에 기여하고 마지막 타격을 번갈아 합니다. Core 1회, death 식재료, 비기여자/늦은 기여자·죽은 대상·duplicate·respawn·Inventory/Gold 불변·Party 없이 협동을 확인합니다. receipt와 서버 지급 시점은 유지하고 cosmetic만 death/recoil 뒤로 지연했습니다.

Body/Horn sound는 현재 짧은 built-in landing sample의 pitch/volume를 구분합니다. 별도 원본 Body/Horn/Heavy WAV를 제작했지만 Roblox에 업로드하지 않았습니다. 소리/모양이 단단한 Horn hit로 읽히는지 확인하고 승인한 audio ID로 교체할 수 있습니다.

Imported MeshPart rig 로드·첫 준비 시간·2–4인 mobile frame time/메모리·streaming/respawn을 기록합니다. 동일 imported template을 clone하여 사용하며 runtime mesh 생성 API는 호출하지 않습니다. Motor6D pose, horn swap, streaming/respawn을 별도 확인합니다.

테스트 날짜/Studio 버전/기기/R6·R15/2·4인/각 PASS·FAIL/Output/영상·스크린샷을 보고합니다. 어떤 필수 항목이라도 미검증·실패면 Phase 1 acceptance를 보류합니다. Phase 2로 넘어가지 않습니다.
