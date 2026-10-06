# TECH ARCHITECTURE

## 1. Place 구성
Experience:
- World Place
- Restaurant Place

향후:
- Large Region Place 추가 가능

## 2. 서버 권한
반드시 서버:
- Damage
- Monster death
- Contribution
- Drop roll
- Inventory change
- Cooking material consumption
- Dish sale
- Gold
- Renown
- Recruitment result
- Enhancement result
- Session settlement
- Blessing activation

Client:
- input intent
- presentation
- local UI
- non-authoritative visual prediction

## 3. 추천 구조
```text
ReplicatedStorage
  Shared
    Config
    Types
    Utilities
    Remotes

ServerScriptService
  Services
    DataService
    SessionService
    PartyService
    TeleportServiceWrapper
    CombatService
    MonsterService
    LootService
    InventoryService
    CookingService
    RestaurantService
    CustomerService
    StaffService
    EconomyService
    EnhancementService
    BlessingService
    AnalyticsService

StarterPlayer
  StarterPlayerScripts
    Controllers
      InputController
      CombatController
      UIController
      PartyController
      RestaurantController
```

## 4. Config
필수 Config:
- StaffRarityConfig
- StaffTraitConfig
- EnhancementConfig
- MonsterConfig
- DropConfig
- RecipeConfig
- RestaurantLevelConfig
- CustomerConfig
- WorldBlessingConfig
- WeaponConfig
- CookwareConfig
- RegionConfig
- EconomyConfig

밸런스 숫자 하드코딩 금지.

## 5. Teleport
World→Restaurant:
1. Host starts prep
2. Create SessionId
3. Lock/escrow pantry
4. Party consent
5. Reserve Restaurant server
6. Teleport
7. Restaurant validates SessionId
8. State Active

Return:
1. LAST ORDER
2. Settling
3. Idempotent settlement
4. Save
5. Closed
6. Teleport party to World

## 6. Studio Testing
TeleportService 실제 Place teleport는 Studio에서 제한.
`Testing.UseFakeTeleport` 지원.

Studio:
- Party
- Session creation
- validation
- fake destination
- data flow

Published QA:
- actual World→Restaurant
- actual Restaurant→World
- party reserved server

## 7. Monster Performance
- 필요 없는 NPC spawn 금지
- Monster budget
- pooling 고려
- Humanoid 남발 금지
- AnimationController/Animator 고려
- simple hitbox
- pathfinding 최소화

## 8. Restaurant Performance
Focus Floor:
Full simulation

Background Open Floor:
numerical server simulation

Closed:
0

## 9. Streaming
World Place StreamingEnabled 전제.
환경 Asset은 reusable mesh/package.

## 10. Security
RemoteEvent payload validation.
Rate limit.
Never trust:
- client gold
- client damage amount
- client item count
- client enhancement result
- client recruitment rarity
- client dish sale price
