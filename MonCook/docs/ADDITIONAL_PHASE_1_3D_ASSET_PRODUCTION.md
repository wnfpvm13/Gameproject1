# ADDITIONAL PHASE 1 INSTRUCTION — 3D Modeling & Asset Production

Phase 1에서는 코드만 구현하지 말고 **실제 플레이에 사용할 3D Asset V1도 함께 제작한다.**

Greybox만으로 Phase 1을 종료하지 않는다.

단, 모든 에셋을 Final Art 수준으로 만드는 것이 아니라 다음 우선순위를 따른다.

> Hornboar ≈ Starter Cleaver > Hornboar 재료 > Greenwood 환경 소품

---

# 1. Art Direction

기존 `ART_BIBLE.md` 기준을 따른다.

스타일:

- 밝은 판타지
- Stylized Low Poly
- 읽기 쉬운 실루엣
- 과도한 사실주의 금지
- 과도하게 어둡거나 공포스러운 디자인 금지
- 모바일에서도 형태가 잘 보이도록 큰 형태 중심
- 텍스처 디테일보다 형태와 색 분리 우선

Roblox 캐릭터와 같이 있을 때 지나치게 사실적으로 보이면 안 된다.

---

# 2. 이번 Phase 필수 3D Asset

## A. Hornboar

Asset ID:

`MON_Hornboar_V1`

이번 Phase의 최우선 모델.

디자인:

- 멧돼지 기반
- 판타지 몬스터
- 일반 멧돼지보다 크고 단단한 체형
- 큰 어깨
- 낮은 중심
- 돌진하기 좋은 실루엣
- 커다란 마법성 뿔
- 등 또는 어깨에 작은 판금/각질 느낌
- 눈은 공격적이지만 고어/호러 금지

색 방향:

- 짙은 갈색 털
- 따뜻한 베이지/갈색 피부
- 뿔은 상아색 + 아주 약한 마력 포인트
- 지나치게 회색/검정 일색 금지

목표:

멀리서 보더라도:

> “저건 뿔 달린 돌진형 멧돼지 몬스터다.”

가 바로 보여야 한다.

---

# 3. Hornboar 구조

Visual Mesh와 Gameplay Hitbox를 반드시 분리한다.

예:

```text
MON_Hornboar_V1
├ Root
├ Visual
│ ├ Body
│ ├ Head
│ ├ Horn_L
│ └ Horn_R
│
├ Gameplay
│ ├ HIT_Body
│ └ HIT_Horn
│
└ Rig
```

실제 Mesh 자체 Collision에 Combat을 의존하지 않는다.

### Horn

뿔은 부위 파괴가 가능해야 하므로 Visual에서도 별도 Object/Part로 유지한다.

가능하면:

```text
Horn_Intact
Horn_Broken
```

또는 별도 visibility state가 가능하도록 만든다.

Horn Break 시:

- 정상 뿔 숨김
- 부러진 뿔 stump 표시

가 가능해야 한다.

---

# 4. Hornboar Poly Budget

V1 목표:

**약 3,000 ~ 6,000 triangles**

불필요하게 고밀도 Mesh를 만들지 않는다.

작은 디테일은 geometry보다:
- 단순 면
- 색
- material
로 해결한다.

---

# 5. Hornboar Rig

Phase 1 Combat에서 실제 Animation을 넣을 수 있도록 기본 Rig를 만든다.

최소 Bone/Joint:

```text
Root
Spine
Neck
Head

FrontLeg_L
FrontLeg_R
BackLeg_L
BackLeg_R

Horn 또는 Head child
```

꼬리를 넣는다면:

```text
Tail
```

정도만.

복잡한 facial rig 불필요.

---

# 6. Hornboar Animation Set

최소:

- Idle
- Walk
- Run
- Alert
- ChargeWindup
- Charge
- Headbutt
- HitReact
- Stagger
- Death

모든 Animation을 반드시 완성해야 한다는 뜻은 아니지만,

Phase 1 Studio 플레이에서는 최소:

- Idle
- Walk/Run
- Charge
- Attack
- Hit
- Death

를 구분할 수 있어야 한다.

임시 애니메이션이라도 State가 읽혀야 한다.

---

# 7. Starter Cleaver

Asset:

`WPN_StarterCleaver_V1`

스타일:

- 판타지 정육도 + 사냥용 검 중간
- 한눈에 Cleaver
- 지나치게 잔혹하거나 피 묻은 표현 금지
- 두꺼운 blade
- 짧은 손잡이
- 초반 무기답게 단순하지만 매력적인 silhouette

Poly 목표:

약 1,000 ~ 2,500 triangles.

Visual과 Combat 판정은 분리.

---

# 8. Ingredient Models

다음 재료의 간단한 V1 3D Model을 만든다.

### Hornboar Meat

`ING_HornboarMeat_V1`

- 밝은 판타지 식재료
- 생고기이지만 고어스럽지 않게
- 게임 재료처럼 정돈된 형태

### Arcane Fat

`ING_ArcaneFat_V1`

- 일반 지방과 차별화
- 약간 빛나는 크림/황금색
- 판타지 재료라는 느낌

### Marbled Loin

`ING_MarbledLoin_V1`

Rare Ingredient.

일반 Hornboar Meat보다 확실히 고급스럽게.

- 좋은 마블링
- 깨끗한 단면
- 약간 특별한 presentation

### Horn Core

`MAT_HornCore_V1`

Horn Break Material.

- 작은 잘린 뿔/핵
- 상아 + 마력 핵
- 음식보다는 강화 재료로 읽혀야 함

---

# 9. Drop 표현

실제 Personal Loot는 서버가 바로 Inventory로 지급한다.

따라서 Ingredient 3D Model을 월드에서 다른 사람이 주워가는 구조는 만들지 않는다.

하지만 획득 순간:

```text
Monster
↓
Ingredient visual pop
↓
Player 방향으로 이동 / fade
↓
Inventory 획득
```

같은 짧은 연출에 사용할 수 있도록 모델을 제작한다.

---

# 10. Greenwood Environment V1

사냥 테스트 공간도 완전히 Baseplate처럼 두지 않는다.

최소 제작:

- Stylized tree 2~3종
- Rock 2~3종
- Bush
- Grass patch
- 작은 stump
- Greenwood sign 또는 작은 landmark

다만 Hornboar보다 작업 우선순위 낮음.

모델을 지나치게 많이 만들지 않는다.

목적은:

> Hornboar와 전투가 실제 게임 속에서 일어나는 느낌

을 만드는 것이다.

---

# 11. Modeling Workflow

가능한 경우 다음 Hybrid Workflow 사용.

## Roblox Studio

다음은 Studio Part / MeshPart 기반으로 빠르게 제작 가능:

- Greybox
- Hitbox
- Spawn marker
- 간단한 environment prop

## Blender

다음은 Blender 제작 우선:

- Hornboar
- Starter Cleaver
- Hero ingredient
- 향후 Boss / Hero Food

가능한 환경이라면 Codex는 Blender Python Script를 작성해서
반복 가능한 Asset 생성/수정 Pipeline을 만들어도 된다.

예:

```text
art/blender/
    build_hornboar.py
    build_starter_cleaver.py
```

단순히 Python script만 만들고 실제 결과를 검증하지 않은 상태를
“3D 모델 완료”로 보고하지 않는다.

실제로 Roblox에서 사용할 결과물까지 생성 가능해야 한다.

---

# 12. Asset Source 보존

가능한 경우 Source와 Game Asset을 구분한다.

예:

```text
art/
├ blender/
│ ├ Hornboar/
│ ├ StarterCleaver/
│ └ Ingredients/
│
└ exports/
```

Roblox 쪽:

```text
ReplicatedStorage
└ Assets
   ├ Monsters
   ├ Weapons
   ├ Ingredients
   └ Environment
```

Source Asset과 Runtime Asset 이름이 대응되어야 한다.

---

# 13. Asset 교체 구조

Gameplay 코드에서 직접:

```text
workspace.Hornboar.Head.Horn
```

같은 식으로 Visual 내부 구조를 강하게 참조하지 않는다.

MonsterDefinition 또는 Asset Binder를 통해 연결한다.

목표:

나중에 `MON_Hornboar_V2`로 교체해도

- AI
- Damage
- Drop
- Spawn
- Contribution

코드가 거의 바뀌지 않아야 한다.

---

# 14. Visual Quality Check

Hornboar V1 완료 시 다음 카메라에서 확인:

### Close
전투 거리.

### Medium
일반 사냥 거리.

### Far
Spawn을 발견하는 거리.

세 거리 모두에서 실루엣이 읽혀야 한다.

특히 뿔은 Medium 거리에서도 보여야 한다.

---

# 15. Horn Break Visual QA

반드시 실제 Studio에서 확인:

```text
정상 Hornboar
→ Horn 타격
→ Horn HP 0
→ 뿔 파괴
→ Broken visual
→ Horn Core 획득 연출
```

Visual과 Gameplay State가 일치해야 한다.

---

# 16. Animation / Hitbox QA

Animation과 실제 공격 판정이 지나치게 어긋나지 않도록 한다.

Charge:

```text
Windup
→ Movement
→ Hit Window
→ Recover
```

Player가 시각적으로 안 맞았는데 Damage를 받는 현상을 최소화한다.

Headbutt도 동일.

---

# 17. Placeholder 정책

아직 없는 Final Asset은 다음 이름을 사용할 수 있다.

```text
*_PLACEHOLDER
```

하지만 이번 Phase 종료 시:

### Placeholder로 끝내면 안 되는 것

- Hornboar
- Starter Cleaver

이 둘은 최소 **V1 Game Asset** 상태까지 만든다.

Ingredient/Environment는 품질 상황에 따라 V1 또는 polished placeholder 가능.

---

# 18. 완료 보고에 Art 항목 추가

Phase 1 완료 보고에 다음 항목을 별도로 포함한다.

1. 구현 내용
2. 브랜치/PR
3. 코드 변경
4. **제작한 3D Asset**
5. **Asset별 상태**
   - Final
   - V1
   - Placeholder
6. Triangle 수 / Rig 상태
7. Animation 상태
8. Studio 테스트 결과
9. 자동 테스트 수
10. 남은 Art TODO

전체 소스 PC 설치 ZIP은 만들 필요 없다.

필요한 경우 Studio 확인용 `.rbxlx`에 모델을 포함한다.