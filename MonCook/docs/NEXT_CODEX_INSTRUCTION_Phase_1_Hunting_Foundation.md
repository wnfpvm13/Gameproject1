# NEXT CODEX INSTRUCTION — Phase 1 Hunting Foundation

Phase 0 / 0.8 Foundation은 종료되었다.

이번 Phase의 목표는 **Greenwood의 첫 사냥 공급망을 실제 플레이 가능한 형태로 완성하는 것**이다.

핵심 Vertical Slice:

> 플레이어가 Hornboar를 발견한다  
> → Basic / Heavy / Dodge로 전투한다  
> → 뿔을 별도로 파괴할 수 있다  
> → Hornboar를 처치한다  
> → Personal Loot로 식재료와 재료를 획득한다  
> → Inventory에서 확인한다

Restaurant / Cooking은 이번 Phase에서 구현하지 않는다.

---

## 0. 작업 시작 전

반드시 최신 Foundation PR이 `main`에 병합된 상태를 기준으로 한다.

작업 전 읽기:

- `CODEX_START_HERE.md`
- `MASTER_GDD.md`
- `MONSTER_BIBLE.md`
- `COMBAT_WEAPONS.md`
- `INGREDIENT_RECIPE_BIBLE.md`
- `DATA_SCHEMA.md`
- `TECH_ARCHITECTURE.md`
- `CODEX_RULES.md`
- `IMPLEMENTATION_PLAN.md`

새 설계가 기존 Foundation 계약과 충돌하면 임의 수정하지 말고 보고한다.

---

# 1. 작업 범위

이번 Phase에서 구현:

### Combat
- Basic Attack
- 3-hit combo
- Heavy Attack
- Dodge
- server-authoritative damage
- simple facing / mobile assist hook

### Monster
- Hornboar
- Spawn
- AI
- Charge
- Headbutt 또는 기본 근접공격
- Body HP
- Horn Part HP
- Horn Break
- Death / despawn
- Respawn

### Loot
- Personal Loot
- Guaranteed ingredient
- Rare ingredient roll
- Part Break reward
- Contribution check

### Inventory
- Ingredients
- Materials
- server-authoritative addition
- minimal inventory UI
- 획득 알림

이번 Phase에서 구현하지 않음:
- Mawcap
- Slime
- Drakelet
- Twin Ogre
- Cooking
- Restaurant
- Staff
- Gold reward
- Expedition actual combat
- Quick Match

---

# 2. Branch 구성

Foundation 이후 다음 브랜치 구조를 사용한다.

```text
main
 ├ feature/combat
 ├ feature/monsters
 ├ feature/inventory
 └ integration/hunting
```

가능하면 공통 Config/Type/API 계약을 먼저 정의한다.

Feature branch끼리 같은 파일을 불필요하게 동시에 수정하지 않는다.

### feature/combat
담당:
- CombatService
- combat remotes
- input/controller
- weapon combat definition
- dodge
- server hit validation

### feature/monsters
담당:
- MonsterService
- Hornboar AI
- spawn
- hitboxes
- horn break
- contribution

### feature/inventory
담당:
- InventoryService
- ingredient/material mutation
- pickup/reward presentation
- inventory minimal UI

### integration/hunting
위 세 기능을 통합하고 실제 Hornboar 한 사이클을 완성한다.

---

# 3. Shared Hunting Field

이번 Hornboar는 **Expedition가 아니라 Shared Hunting Field**에 배치한다.

테스트 지역:

`Greenwood Outskirts_PLACEHOLDER`

World Place 내부.

Greybox만 사용해도 된다.

필수:
- Spawn point
- Hornboar spawn area
- 간단한 바위/나무 placeholder
- 다른 플레이어가 같은 Hornboar를 공격할 수 있음

튜토리얼 전용 개인 Hornboar는 아직 필수 아님.
단 향후 개인 tutorial encounter로 확장 가능한 구조는 유지한다.

---

# 4. Player Combat

## Basic Attack

Starter Cleaver 사용.

3-hit combo:

```text
Attack1
→ Attack2
→ Attack3
```

요구:
- 일정 시간 안에 다음 입력 시 combo 진행
- 너무 늦으면 Attack1로 reset
- 공격 중 무한 spam 금지
- animation marker 또는 명시적 attack window 사용 가능

실제 Damage 판정은 서버가 결정한다.

Client가 보내는 것:

```text
AttackIntent
AttackType
Facing / target hint
```

Client가 절대로 보내면 안 되는 것:

```text
Damage = 9999
HitMonster = true
HornBroken = true
```

---

# 5. Heavy Attack

특징:
- Basic보다 느림
- 더 높은 Damage
- 훨씬 높은 PartBreakPower

Hornboar 뿔을 노릴 때 유리해야 한다.

정확한 Damage는 Config.

---

# 6. Dodge

초기 Dodge는 복잡하게 만들지 않는다.

- 짧은 이동
- cooldown
- 위치 회피 중심

Hardcore Souls-like invulnerability 시스템은 만들지 않는다.

필요하면 아주 짧은 보호 window를 Config hook으로 준비할 수 있지만,
과도한 i-frame 의존 금지.

Stamina 시스템 없음.

---

# 7. Mobile Combat

PC만 작동하면 완료 아님.

PC:
- Mouse / keyboard

Touch:
- Attack
- Heavy
- Dodge

Gamepad hook:
- input action abstraction

모바일에서 플레이어가 몬스터 근처를 향하고 있으면
약한 facing correction / target assist 가능.

자동 공격은 구현하지 않는다.

---

# 8. Hornboar

Config ID:

```text
Hornboar
```

Placeholder Model 이름:

```text
MON_Hornboar_PLACEHOLDER
```

Horn separate:

```text
PART_Hornboar_Horn
```

Hitbox:

```text
HIT_Hornboar_Body
HIT_Hornboar_Horn
```

Mesh collision 자체를 전투 판정에 사용하지 않는다.

---

# 9. Hornboar AI

Hornboar는 첫 몬스터이므로 읽기 쉬워야 한다.

최소 State:

```text
Idle
Roam
Alert
Chase
Windup
Attack
Recover
Stagger
Dead
```

핵심 공격:

### Headbutt
근거리 기본공격.

### Charge
Hornboar의 정체성을 만드는 공격.

흐름:

```text
Player 발견
→ 잠깐 방향 고정
→ Charge Telegraph
→ 돌진
→ 지나간 뒤 Recover
```

플레이어가 보고 피할 시간이 있어야 한다.

즉시 돌진 금지.

---

# 10. Horn Break

Horn은 Body와 별도 Part HP를 가진다.

Heavy Attack은 높은 PartBreakPower.

예:

```text
BodyHP
HornHP
```

HornHP가 0:

1. Horn break event
2. 깨지는 VFX/SFX placeholder
3. Horn visual → Broken state
4. `Horn Core` Personal Reward eligibility
5. 이후 Horn hitbox disabled

Horn을 먼저 부쉈다고 Hornboar가 즉시 죽지 않는다.

---

# 11. Hornboar Drops

Config 기반.

기준 설계:

### Guaranteed
`Hornboar Meat`

### Common / Uncommon
`Arcane Fat`

### Rare
`Marbled Loin`

### Part Break
`Horn Core`

Monster가 Gold를 직접 드롭하면 안 된다.

정확한 drop chance는 `DropConfig`.

테스트 수치에는:

```text
TODO_BALANCE
```

표시.

---

# 12. Personal Loot

Last Hit 방식 금지.

Hornboar encounter에 기여한 플레이어별로 독립 Roll.

예:

```text
Player A
→ Meat
→ Fat

Player B
→ Meat
→ Marbled Loin
```

실제 3D drop을 다른 플레이어가 훔치는 구조 금지.

획득 결과는 각 플레이어 개인에게만 지급.

---

# 13. Contribution

AFK 방지.

Contribution 후보:

- Body Damage
- Part Damage
- Encounter participation

Hornboar 같은 일반 몬스터에서는 기여 기준을 매우 낮게 둔다.

예:

한 번이라도 의미 있는 공격에 참여하면 대부분 reward eligibility.

Boss에서 더 엄격하게 확장 가능하도록 구조만 준비.

---

# 14. Inventory

PlayerData 기존 구조 사용.

```text
Inventory.Ingredients
Inventory.Materials
```

Category:

Hornboar Meat:
`Protein`

Arcane Fat:
`Special` 또는 설계 Config 기준

Marbled Loin:
`Protein`

Horn Core:
`Material`

Inventory 변경은 반드시 서버.

Client는:
- 표시
- filter
- selection

만 담당.

---

# 15. 최소 Inventory UI

이번 Phase에서는 최종 Inventory UI까지 만들지 않는다.

최소 기능:

Tabs:
- Ingredients
- Materials

아이템 표시:
- 아이콘 placeholder
- 이름
- 수량

예:

```text
Ingredients

Hornboar Meat    ×12
Arcane Fat        ×3
Marbled Loin      ×1
```

Materials:

```text
Horn Core         ×2
```

향후 Recipe 연결을 고려한 구조.

---

# 16. 획득 UI

기본 재료:

```text
Hornboar Meat ×2
```

작은 알림.

Rare:

```text
✨ RARE INGREDIENT
Marbled Loin
```

Part Break:

```text
Horn Broken!
Horn Core acquired
```

화면을 오래 가리지 않는다.

---

# 17. Monster Respawn

Shared Field이므로 Respawn 필요.

목표:
사냥터가 비지 않도록 한다.

Spawn system은:

```text
SpawnZone
MaxAlive
RespawnDelay
MonsterId
```

Config 기반.

Hornboar 하나를 workspace에 영구 하드코딩하지 않는다.

향후 같은 Spawner로 Mawcap/Slime 사용 가능하게 한다.

---

# 18. Multiplayer

Studio Server & Clients 2~4명에서 확인.

반드시:

- 두 플레이어가 같은 Hornboar 공격 가능
- Last hit 독점 없음
- 두 플레이어 Personal Loot
- Horn break reward 중복 exploit 없음
- 죽은 몬스터 반복 공격으로 reward 재지급 없음
- Respawn 정상

Party가 아니어도 기여하면 Personal Loot를 받을 수 있다.

---

# 19. Server Security

Remote 검증:

Attack rate
Attack state
Distance
Weapon equipped
Monster alive
Hitbox validity
Cooldown

Client가 먼 거리에서 공격 요청을 보내도 거절.

중복 Attack packet으로 Damage 여러 번 적용 금지.

죽은 Monster에 reward 요청 금지.

Client가 Drop roll을 요청하는 구조 금지.

---

# 20. Config

추가/확장:

```text
WeaponConfig
CombatConfig
MonsterConfig
DropConfig
IngredientConfig
SpawnConfig
```

예:

```lua
Hornboar = {
    MaxHealth = TODO_BALANCE,
    MoveSpeed = TODO_BALANCE,

    Horn = {
        Health = TODO_BALANCE,
    },

    Attacks = {
        Headbutt = {...},
        Charge = {...},
    }
}
```

서비스 로직에 밸런스 숫자 하드코딩하지 않는다.

---

# 21. Analytics Hook

실제 Analytics 전송 시스템이 아직 미완성이면 Hook만 준비.

Events:

```text
MonsterEncounterStarted
AttackUsed
HeavyAttackUsed
DodgeUsed
PartBroken
MonsterKilled
IngredientObtained
RareIngredientObtained
```

특히:

```text
FirstHornboarKilled
FirstIngredientObtained
```

FTUE에서 중요.

---

# 22. Art

이번 Phase는 Greybox 허용.

Hornboar Placeholder가 예쁘지 않아도 된다.

하지만 다음은 구조적으로 구분:

```text
VisualModel
BodyHitbox
HornHitbox
Root
```

나중에 Blender `MON_Hornboar` Package로 교체해도 AI/Combat 코드를 수정하지 않도록 한다.

---

# 23. 테스트

기존 **176개 테스트 전부 유지**.

새 자동 테스트 최소:

### Combat
- combo progression
- combo reset
- cooldown
- heavy part power
- distance validation
- duplicate intent protection
- dead target rejection

### Monster
- AI state transition
- charge telegraph
- damage
- horn damage
- horn break once
- death once
- respawn

### Contribution
- one contributor
- two contributors
- non-contributor
- part contributor
- duplicate reward prevention

### Loot
- guaranteed drop
- rare roll
- part reward
- correct inventory bucket
- no Gold

### Inventory
- add
- stack
- invalid item rejection
- server-only mutation
- persisted value

---

# 24. Studio 수동 QA

반드시 확인할 항목:

1. Hornboar가 돌아다님
2. 플레이어 접근 시 반응
3. Charge가 미리 보임
4. Basic Attack 3 combo
5. Heavy Attack
6. Dodge
7. Horn 별도 타격 가능
8. Horn 파괴
9. Hornboar 처치
10. Ingredient 획득
11. Inventory 수량 증가
12. Respawn
13. 2인 동시 공격
14. 두 명 Personal Loot
15. 모바일 Attack/Heavy/Dodge

---

# 25. Phase 1 Acceptance

Phase 1 완료 조건:

> World에서 플레이어가 Hornboar를 발견해 싸우고, 뿔을 파괴하고, 처치한 뒤 각자 식재료를 받아 Inventory에서 확인할 수 있다.

그리고:

- server authoritative
- Personal Loot
- no Gold drop
- multiplayer
- mobile
- Config driven
- regression tests pass

모두 충족해야 한다.

---

# 완료 후

이번 Phase가 끝나면 새 콘텐츠로 넘어가지 말고 보고한다.

완료 보고:

1. 구현 내용
2. 브랜치/PR
3. 변경 파일
4. 테스트 수
5. Studio 미검증
6. 알려진 문제
7. Phase 2 영향

전체 소스 PC 설치 ZIP은 만들 필요 없다.

필요 산출물:
- GitHub PR
- `IMPLEMENTATION_STATUS.md`
- Studio 수동 QA용 `.rbxlx`
정도만 제공한다.