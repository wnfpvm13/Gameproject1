# IMPLEMENTATION PLAN

## Phase 0 — Foundation
목표:
게임 전체가 공유할 계약을 먼저 고정.

### 0.1 Repo / Folder
- Shared Config
- Types
- Remotes
- Services
- Controllers

### 0.2 Config Registry
- Region
- Monster
- Drop
- Recipe
- Weapon
- Cookware
- Staff
- Restaurant
- Customer
- Enhancement
- Economy
- Blessing

### 0.3 Data Schema
- PlayerData
- schema version
- migration skeleton

### 0.4 DataService
- load
- save
- update
- session lock
- test profile

### 0.5 Party
Studio 2~4 fake players:
- create
- join
- leave
- leader
- max 4

### 0.6 Restaurant Session
- create SessionId
- pantry escrow
- state machine
- idempotent settlement skeleton

### 0.7 Teleport abstraction
- FakeTeleport in Studio
- real Teleport wrapper for published test

### Phase 0 Acceptance
- Studio multi-client party works
- 1-player published Reserved Restaurant teleport works
- data persists World→Restaurant→World
- duplicate settlement cannot duplicate rewards
- teleport failure can rollback pantry
- errors are logged

---

## Phase 1 — Vertical Slice Foundation branches

### feature/combat
- input abstraction
- Basic 3 hit
- Heavy
- Dodge
- hit validation
- starter Cleaver

### feature/monsters
- MonsterConfig
- Hornboar
- part hitbox
- horn break
- AI
- spawn budget

### feature/inventory
- ingredients/materials
- pickup
- server mutation

### integration/hunting
Combat + Hornboar + Loot + Inventory

Acceptance:
- Hornboar can be fought on mobile/PC
- horn break gives special material
- personal loot
- exploit-resistant

---

## Phase 2 — Restaurant Vertical Slice

### feature/cooking
- RecipeConfig
- Hornboar Steak
- cooking station
- quality
- ingredient consumption
- Perfect

### feature/restaurant
- CLOSED/OPEN/CLOSING
- customer state machine
- order
- payment
- settlement

### feature/staff
- first Rare Server
- basic Server automation
- basic Chef placeholder

### integration/restaurant
- Hornboar Steak order
- player cook
- serve
- Gold/Renown
- CLOSE

Acceptance:
- no OPEN = no customer/revenue
- ingredient consumed exactly once
- dish sold exactly once
- settlement duplicate-safe

---

## Phase 3 — Full Vertical Slice
World → Hornboar → Restaurant → Shift → Upgrade → World

Add:
- Blacksmith basic enhancement
- Grill basic enhancement
- Recruitment basic Contract
- Monster Book / Recipe Book minimal UI
- FTUE 5 min flow

Art Wave 1:
- Hornboar final
- Twin Ogre final
- Hornboar Steak final
- Twin Ogre Prime Feast final
- Hearthcross center
- Greenwood slice
- Restaurant kitchen

Gate:
이 장면이 재미/아트/모바일에서 통과하기 전 Sunscar 대량 제작 금지.

---

## Phase 4 — Greenwood Complete
- Mawcap
- Glutton Slime
- Razorvine Drakelet
- Twin Ogre
- Greenwood foods 8
- Greenwood environment
- Monster Mastery
- Recipe discovery
- Staff rarity/recruitment
- infinite enhancement base
- Restaurant expansion base

---

## Phase 5 — Sunscar
- Cinderhorn
- Basilisk
- Cockatrice
- Sandmaw
- Minotaur
- foods 8
- Minotaur Arena
- second weapon/cookware tiers
- progression verification

---

## Phase 6 — Multiplayer Restaurant
- actual 2~4 party teleport QA
- helper permission
- helper rewards
- Host reconnect grace
- return party
- anti-duplication stress tests

---

## Phase 7 — Endless Systems
- floor modules
- Operating Floor Capacity
- Focus Floor full sim
- Background Open Floor sim
- Demand vs Capacity
- Manager hooks for future

---

## Phase 8 — BM
- Blessing Tokens
- Tailwind
- Hunter's Rhythm
- Bounty
- server announcement
- policy-safe store UI
- cosmetics hooks

Fortune rare-drop modifier는 별도 후속.

---

## Phase 9 — Analytics / Performance
- Funnel
- Economy
- Shift metrics
- MicroProfiler
- 20-player stress
- low-end mobile
- Streaming
- NPC budgets

---

## Branch Plan
Foundation 먼저.

이후 병렬:
- feature/combat
- feature/monsters
- feature/restaurant
- feature/cooking
- feature/staff
- feature/party
- feature/ui
- feature/economy

Integration:
- integration/hunting
- integration/restaurant
- integration/core-loop

main 병합 조건:
- feature test
- reviewer
- integration test
- no known duplication/exploit bug
