# MASTER GDD — The Last Recipe

## 1. 게임 정체성
장르:
- Monster Hunting
- Restaurant Management
- Co-op Adventure
- Long-term Progression

핵심 판타지:
> 몬스터를 잡아 식재료를 구하고, 그 재료를 요리해 내 식당을 끝없이 성장시킨다.

톤:
- 밝고 경쾌한 판타지
- 다크판타지/고어 금지
- 몬스터는 위협적이되 기괴하거나 잔혹하게 표현하지 않음
- 음식은 매우 맛있어 보이게 제작

## 2. 서버/공간
### World Place
- 목표 MaxPlayers: 20
- Hearthcross 마을
- 사냥지역
- 파티 모집
- 직원 모집
- 강화
- 다른 플레이어의 Restaurant Facade

### Restaurant Place
- 1~4인 Reserved Server
- Host의 식당
- OPEN일 때만 손님/주문/매출 활성
- CLOSED/사냥/오프라인 상태 수익 0

## 3. 플레이 루프
### Expedition
- 오늘 메뉴/재고 확인
- 목표 재료 선택
- 혼자 또는 파티로 사냥
- Personal Loot
- 부위파괴로 특수 재료 획득
- 자연채집 병행

### Restaurant Shift
- Menu / Staff / Active Floors 준비
- OPEN
- 고객 입장
- Player 또는 Chef가 요리
- Player 또는 Server가 서빙
- Dinner Rush 가능
- LAST ORDER
- 정산

### Investment
Gold 소비:
- 식당 확장
- 직원 Recruitment/Training
- 무기 강화
- 조리도구 강화

Renown:
- Restaurant Level 전용

## 4. 장기 성장
- Restaurant Level: 상한 없음
- Restaurant Floors: 지속 확장
- Weapon Enhancement: 상한 없음
- Cookware Enhancement: 상한 없음
- Staff: Common → Mythic
- Recipe Book: 지역 업데이트마다 증가
- Monster Book: 지역 업데이트마다 증가
- Decoration: 지속 확대

## 5. 핵심 차별점
1. Monster Cuisine
2. Part Break Ingredients
3. Active Restaurant Shift
4. Endless Restaurant Growth
5. 20-player Hunter Town → 1~4 player Restaurant
6. 음식 자체가 강력한 시각적 보상

## 6. 첫 공개 테스트 범위
World:
- Hearthcross
- Greenwood
- Sunscar

Monsters:
- 10종

Food:
- 16종

Weapons:
- Cleaver / Great Cleaver / Hunting Spear

Cookware:
- Pan / Grill / Pot

Staff:
- Chef / Server
- 5 rarity

Customers:
- Villager / Traveler / Hunter / Merchant / Gourmet(또는 Noble 중 일부)

## 7. Post-launch
초기 제외:
- Pet
- Guild
- PvP
- Free Trade
- Fishing
- Farming
- Dragon
- Large Raid
- Season Pass

Dragon:
- 장기 미스터리
- Recipe Book 마지막 `???`
- 출시 초반 실체 공개 금지


## 8. Party & Expedition 구조 — Design Lock 1.1
- Party ID 직접 입력은 실제 플레이 UX에서 제거하고 QA 전용으로 유지
- Public Party: 같은 Hearthcross 서버 Party Finder 노출
- Private Party: 초대 전용
- Quick Match: Cross-server 후속 V1.5
- Shared Hunting Field: 초보/일반 파밍/우연한 협동
- Expedition Reserved Server: 1~4인 정예/보스/대형 사냥터
- Expedition 종료 후 Repeat / Host Restaurant / Hearthcross 선택
