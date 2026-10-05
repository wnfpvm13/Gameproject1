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
