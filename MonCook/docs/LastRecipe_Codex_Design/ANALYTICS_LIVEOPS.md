# ANALYTICS & LIVEOPS

## 1. FTUE Funnel
Joined
→ FirstHornboarEncounter
→ FirstHunt
→ FirstIngredient
→ TrainingCook
→ FirstDishCooked
→ FirstServe
→ FirstSale
→ RestaurantUnlocked
→ FirstRestaurantSession
→ FirstShiftComplete
→ ReturnWorld
→ SecondExpedition

핵심 질문:
`첫 Shift 이후 다시 사냥하러 가는가?`

## 2. Core Events
- HuntStarted
- MonsterKilled
- PartBroken
- IngredientObtained
- RecipeDiscovered
- DishCooked
- DishSold
- RestaurantOpened
- RestaurantClosed
- ShiftCompleted
- StaffRecruited
- EnhancementAttempt
- EnhancementSuccess
- RestaurantExpanded

## 3. Economy
- GoldEarnedPerShift
- GoldSpentRestaurant
- GoldSpentRecruitment
- GoldSpentWeapon
- GoldSpentCookware
- GoldBalance
- RecruitmentCount
- EnhancementAttempts
- EnhancementSuccessRate

## 4. Restaurant
- ShiftDuration
- OrdersPerShift
- OrdersMissed
- ManualCookCount
- ChefCookCount
- ManualServeCount
- ServerServeCount
- PerfectCount
- ActiveFloorCount

## 5. Social
- PartyCreated
- PartyJoined
- PartyHunt
- RestaurantPartySession
- HelperActions
- RestaurantFacadeViewed

## 6. LiveOps Unit
업데이트 기본 단위 = Region Pack

Region Pack:
- Region
- 4+ Monsters
- Boss
- Ingredients
- 8~12 Recipes
- Upgrade Materials
- Staff Traits
- Decor Theme
- Short Story

## 7. Post-launch Idea Gate
새 시스템은 바로 Core에 추가하지 않는다.
다음 파일/백로그로 보낸다:
- Pets
- Guild
- Trade
- PvP
- Fishing
- Farming
- Raid
- Season
- Dragon

Core Retention이 검증된 뒤만 추가 검토.


## 8. Party / Expedition 추가 이벤트
- PublicPartyCreated
- PrivatePartyCreated
- PartyFinderOpened
- PublicPartyJoined
- PartyInviteAccepted
- ReadyCheckStarted
- ReadyCheckAccepted
- ReadyCheckStayed
- ExpeditionStarted
- ExpeditionCompleted
- ExpeditionRepeated
- ExpeditionToRestaurant
- QuickMatchQueued (V1.5)
- QuickMatchMatched (V1.5)
