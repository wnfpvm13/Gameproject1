# DATA SCHEMA

## 1. 원칙
- 서버 권한
- SchemaVersion 필수
- Migration 지원
- 모든 ID는 stable string
- Config key와 Data key 분리
- Client는 authoritative value를 결정하지 않음

## 2. PlayerData 개념안
```lua
PlayerData = {
    SchemaVersion = 1,

    Currencies = {
        Gold = 0,
    },

    Progression = {
        RestaurantLevel = 1,
        RestaurantRenown = 0,
        RegionUnlocks = {"Greenwood"},
    },

    Inventory = {
        Ingredients = {},
        Materials = {},
    },

    Equipment = {
        EquippedWeaponId = "StarterCleaver",
        Weapons = {},
        Cookware = {},
    },

    Recipes = {
        Discovered = {},
        Mastery = {},
    },

    Monsters = {
        Discovery = {},
        Mastery = {},
    },

    Staff = {
        Owned = {},
        ActiveRestaurantStaff = {},
        RecruitmentReputation = 0,
    },

    Restaurant = {
        ExpansionPoints = 0,
        Floors = {},
        BuiltModules = {},
        DecorationPlacements = {},
        SignatureDishId = nil,
        FacadeStyle = "Default",
    },

    Cosmetics = {
        Owned = {},
        Equipped = {},
    },

    Monetization = {
        BlessingTokens = {},
    },

    AnalyticsFlags = {},
}
```

## 3. Weapon Instance
```lua
{
    InstanceId = "uuid",
    WeaponConfigId = "HunterCleaver",
    EnhancementLevel = 0,
    StabilizedFloor = 0,
    EnhancementFocus = 0,
}
```

## 4. Cookware
```lua
{
    InstanceId = "uuid",
    CookwareConfigId = "BasicGrill",
    EnhancementLevel = 0,
    StabilizedFloor = 0,
    EnhancementFocus = 0,
}
```

## 5. Staff Instance
```lua
{
    StaffId = "uuid",
    ArchetypeId = "Chef_A",
    Role = "Chef",
    Rarity = "Epic",
    Level = 1,
    XP = 0,
    Traits = {"MonsterMeatExpert"},
}
```

## 6. Restaurant Session
영구 PlayerData에 진행 중 세션 세부를 무겁게 저장하지 않는다.

Cross-server session:
```lua
{
    SessionId = "uuid",
    HostUserId = 123,
    PartyUserIds = {123,456},
    State = "Preparing", -- Preparing/Teleporting/Active/Settling/Closed
    CreatedAt = 0,
    Pantry = {},
    SettlementVersion = 0,
}
```

## 7. Pantry Escrow
Shift 시작:
Main Inventory → Session Pantry

Restaurant는 Pantry만 소비.

Settlement:
- Used → consumed
- Remaining → return

Teleport failure:
- rollback

## 8. Idempotent Settlement
SessionId 기준 이미 정산된 세션인지 확인.
동일 세션 반복 요청은 동일 결과를 반환하고 경제 반영은 한 번만.

## 9. DataStore
지속 데이터:
DataStore

빠른 임시 cross-server:
MemoryStore

TeleportData:
비민감 식별자만.
예:
- SessionId
- return context

Gold/ingredient의 실제 수치 전달 금지.


## 10. Party Runtime Schema
```lua
Party = {
    PartyId = "uuid",
    LeaderUserId = 123,
    MemberUserIds = {123,456},
    Visibility = "Public",
    Activity = "Free",
    TargetId = "TwinOgre",
    Status = "Forming",
    ReadyStates = {},
}
```

Visibility:
- Public
- Private

Activity:
- Free
- SharedHunt
- Expedition
- Restaurant

Status:
- Forming
- ReadyCheck
- InActivity
- Closed

PartyId는 내부 식별자.

## 11. Expedition Session
```lua
ExpeditionSession = {
    SessionId = "uuid",
    PartyId = "uuid",
    MemberUserIds = {123,456},
    RegionId = "GreenwoodDeepRuins",
    TargetId = "TwinOgre",
    State = "Preparing",
    CreatedAt = 0,
}
```

State:
Preparing / Teleporting / Active / Result / Returning / Closed

## 12. Phase 1 구현 계약

`Inventory.Ingredients[IngredientId]` / `Inventory.Materials[IngredientId]`는 양의 정수 stack map이다. HornCore는 Materials, 나머지 사냥 식재료는 Ingredients이다. 기존 모르는 항목은 보존하며 변경할 stack이 손상된 경우 grant를 거절한다.

선택적 `HuntingReceipts[ReceiptId]`를 기존 schema v1에 추가한다. `GrantedAt`, `Kind`, `MonsterId`, `Items`, `FirstIngredient`, `FirstHornboar`를 저장하고 해당 stack 증가와 같은 DataService.Update에서 commit한다. Restaurant의 SettlementReceipts/SessionId와 독립적이다. 기존 프로필은 필드가 없어도 유효하며 첫 grant에서 추가한다. retry 600초보다 긴 3,600초 보존을 사용하고 만료 entry만 성공한 grant 중 정리한다. 수치는 HuntingConfig의 TODO_BALANCE이다.

기존 `EquippedWeaponId = "StarterCleaver"` 기본값은 내장 starter entitlement로 유지한다. 다른 장비는 소유한 instance의 InstanceId/WeaponConfigId로 해결하며 Weapons 컬렉션을 초기화하지 않는다. `AnalyticsFlags.FirstIngredientObtained`와 `FirstHornboarKilled`는 성공한 개인 grant 시 한 번 기록한다. 첫 처치 flag의 의미는 마지막 타격이 아니라 첫 기여자 처치 보상이다.
