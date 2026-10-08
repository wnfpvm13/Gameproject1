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


## 11. Party Finder / Expedition Architecture
### Party Finder V1
현재 World 서버 안의 Public Party 목록.

필수:
- CreatePublicParty
- CreatePrivateParty
- JoinPublicParty
- Invite
- Leave
- Visibility toggle
- Activity/Target update
- ReadyCheck

### Quick Match V1.5
Cross-server.
MemoryStoreQueue 후보.
TargetId별 queue.

### Expedition
Restaurant와 별도 Reserved Server activity.

추가 서비스 후보:
- PartyDirectoryService
- ExpeditionService
- MatchmakingService (V1.5)

Teleport transport layer는 Restaurant/Expedition이 재사용.
세션 검증은 activity별 service가 담당.

## 12. Phase 1 Shared Hunting 구현

`HuntingRuntime`은 Foundation의 인증 actor/profile/location/travel API를 주입받는 World 전용 Roblox 어댑터이다. Party·ReadyCheck·Restaurant·Expedition core API는 그대로 사용한다.

`MonCookHuntingNetwork`를 기존 Foundation network와 별도로 사용한다. Intent는 Sequence/AttackType/선택 Facing·TargetHint만 받는다. State/Changed는 본인 inventory/action snapshot과 성공한 개인 Loot presentation만 전달한다. grant/roll/reward 요청 remote는 없다.

CombatService/MonsterService/LootService/InventoryService는 Roblox 종속성 없는 순수 서비스이며 어댑터가 physics·time·random·DataService를 제공한다. 게임 플레이와 모델은 stable Config AssetId/Binding으로 연결한다. 시각 모델의 collision은 combat에 사용하지 않고 Body/Horn hitbox, range/arc·line-of-sight, 공격 window를 서버에서 검증한다.

몬스터 reward outbox → 개인 roll 고정 → 기존 DataService의 원자 grant/receipt → 개인 cosmetic 순서이다. AI heartbeat와 저장 worker를 분리한다. 정상 PlayerRemoving/BindToClose에서 DataService Release보다 먼저 bounded flush를 시도한다. 미확정 대기열은 서버 메모리이며 강제 종료/장기 저장 장애의 내구성은 후속 항목이다. 실제 Analytics 전송 대신 BindableEvent hook만 제공한다.
