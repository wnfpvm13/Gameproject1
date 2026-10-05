# THE LAST RECIPE — ALL-IN-ONE CODEX SPEC
> 이 파일은 분리된 `/docs` 문서를 한 파일로 합친 전달용 통합본이다. 실제 저장소에서는 분리 문서를 기준으로 사용한다.


---

# CODEX START HERE

이 문서는 Codex가 작업을 시작하기 전에 반드시 읽어야 한다.

## 1. 구현 철학
이 프로젝트는 "사냥 RPG"와 "식당 타이쿤" 두 게임을 붙이는 프로젝트가 아니다.

코어 루프는 하나다.

`메뉴/재고 확인 → 필요한 몬스터/재료 판단 → 사냥/채집 → 귀환 → Restaurant 입장 → OPEN → 요리/서빙/직원관리 → CLOSE → 정산 → Gold/Renown 투자 → 다음 원정`

사냥은 식당 공급망이고, 식당은 사냥의 경제적 이유다.

## 2. 구현 우선순위
1. Foundation
2. 데이터/Config/서버 권한
3. World ↔ Restaurant 세션/텔레포트
4. Vertical Slice
5. 병렬 기능 개발
6. Integration
7. Public Alpha 콘텐츠 확장

## 3. 첫 Vertical Slice
반드시 아래 한 사이클을 완성한 뒤 범위를 넓힌다.

1. Hearthcross 일부
2. Greenwood 일부
3. Hornboar 사냥
4. Horn 파괴
5. Hornboar Meat 획득
6. Restaurant 1F 이동
7. Hornboar Steak 조리
8. Perfect 품질 가능
9. 손님 주문/서빙
10. Shift 종료
11. Gold/Renown 정산
12. World 복귀
13. 데이터가 정확히 유지

## 4. Codex의 자의적 판단 금지
문서에 없는 대규모 시스템을 임의 추가하지 않는다.
예: PvP, 거래, 펫, 길드, 농사, 낚시, 드래곤 보스, 오프라인 수익.

필요한 값이 미정이면 Config에 합리적인 테스트 값을 두고 `TODO_BALANCE`로 표시한다.

## 5. 브랜치 원칙
`main` 직접 수정 금지.

Foundation 통과 후:
- feature/combat
- feature/monsters
- feature/restaurant
- feature/cooking
- feature/staff
- feature/party
- feature/ui
- feature/economy
- feature/analytics

Integration:
- integration/hunting
- integration/restaurant
- integration/core-loop

각 브랜치는 자기 영역 밖 파일을 불필요하게 수정하지 않는다.


---

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


---

# ART BIBLE

## 1. 핵심 문장
> **몬스터는 판타지스럽고 강렬하게, 세계는 밝고 따뜻하게, 음식은 먹음직스럽게.**

## 2. 스타일
Stylized Low-Poly Fantasy + Food Adventure

금지:
- 칙칙한 회갈색 위주의 다크판타지
- 고어
- 사실적인 도축 연출
- 인간형 몬스터를 사람처럼 보이게 만드는 표현
- 음식의 저품질 블록형 모델

## 3. 색 방향
Hearthcross:
- 따뜻한 목재
- 크림
- 금색
- 밝은 돌색

Greenwood:
- 선명한 초록
- 노랑
- 하늘색
- 따뜻한 갈색

Sunscar:
- 주황
- 금색
- 밝은 붉은 사암
- 높은 명도의 하늘

Mirefen:
- 청록
- 연두
- 보라 발광식물

Frostfang:
- 하늘색
- 흰색
- 밝은 회청색

Ashen:
- 주황 용암
- 붉은 수정
- 검은색은 포인트로만 사용

## 4. Monster 디자인 규칙
70% Silhouette  
20% Signature Part  
10% Detail

예:
- Hornboar = 거대한 전방 뿔
- Twin Ogre = 두 머리
- Minotaur = 거대한 소형 뿔 실루엣
- Basilisk = 눈/꼬리
- Cockatrice = 조류+파충류 혼합 실루엣

## 5. 음식
음식은 Hero Asset이다.

필수:
- 고기 두께/단면
- 그릴 자국
- 소스 윤기
- Steam
- 가니시
- 접시/보드
- 품질 단계별 Presentation 차이

Quality:
- Normal: 기본 plating
- Good: garnish
- Great: garnish + sauce + stronger steam
- Perfect: premium garnish + glaze + plate decoration + sparkle

Boss/Signature Dish:
- 썸네일에 사용 가능한 품질
- 독자적인 모델/접시/구성

## 6. 내부 제작 예산(목표)
Roblox 하드 제한이 아니라 프로젝트 내부 최적화 목표.

- Small prop: 300~1,000 triangles
- Weapon: 1,000~3,000
- Normal monster: 3,000~6,000
- Boss: 8,000~15,000
- Major modular architecture: 1,000~5,000

Texture:
- Small: 256
- Medium: 512
- Hero Food/Boss: 필요 시 1024

## 7. 제작 파이프라인
1. Roblox Studio Parts Greybox
2. Gameplay 검증
3. Blender 최종 모델
4. Roblox Package 교체
5. Mobile performance 테스트


---

# WORLD BIBLE

## 1. Hearthcross
20명이 계속 마주치는 작은 소셜 허브.

핵심 시설:
- Central Hearth
- Expedition Gate
- Restaurant Row
- Hunter Guild
- Recruitment Hall
- Blacksmith
- Kitchen Workshop
- Training Kitchen
- General Store
- Ranking Plaza

Restaurant 내부는 별도 Place.
메인월드에는 Facade/간판/Signature Dish/Restaurant Level을 보여준다.

## 2. 지역 로드맵
1. Greenwood Wilds — 시작
2. Sunscar Canyon — 초기 다음 지역
3. Azure Coast
4. Mirefen Marsh
5. Frostfang Highlands
6. Ashen Frontier
7. Dragon 관련 지역은 계획에 넣지 않고 `???` 유지

## 3. 지역 해금
Restaurant Level + 이전 지역 핵심 퀘스트/보스 완료를 사용한다.
정확한 레벨은 Config.

기준안:
- Greenwood: 시작
- Sunscar: Restaurant Lv.10 근처
- Azure: Lv.25
- Mirefen: Lv.45
- Frostfang: Lv.70
- Ashen: Lv.100

## 4. 사냥지역 밀도
기본 속도 기준:
- 첫 몬스터: 10~20초
- 첫 POI: 30~45초
- 지역 끝: 3~5분
- 거대한 빈 오픈월드 금지

## 5. 지역 이동 추상화
RegionConfig:
- TravelMode = "Local"
- TravelMode = "Teleport"

V0.1 일부 지역은 같은 Place에 배치 가능.
향후 큰 지역은 별도 Place로 옮길 수 있어야 한다.

## 6. Market Demand
글로벌 회전 시스템.
서버 hopping으로 바꿀 수 없게 전 서버가 같은 주기를 사용.

예:
- Meat Craze
- Mushroom Festival
- Soup Weather

보너스는 약 10~20% 방향성 제공 수준.
FOMO 강요 금지.


---

# MONSTER BIBLE

## 1. 원칙
핵심 사냥감은 Monster First.
일반 동물은 핵심 전투 적으로 사용하지 않는다.

각 몬스터는 반드시:
- 실루엣이 다름
- 전투 패턴이 다름
- 고유 식재료 또는 강화재료가 있음
- 부위파괴 여부가 정의됨
- 요리와 연결됨

지성 종족(인간/엘프/드워프 등)은 절대 식재료가 아니다.

## 2. Greenwood
### Hornboar
Role: 기본 사냥감  
Patterns: Headbutt / Charge  
Parts: Horn  
Drops:
- Hornboar Meat
- Arcane Fat
- Marbled Loin
- Horn Core (part break)

### Mawcap
Role: 식물/버섯 몬스터  
Patterns: Slam / Spore AoE  
Drops:
- Mawcap Flesh
- Aromatic Spore
- King Cap

### Glutton Slime
Role: 조미/젤라틴  
Patterns: Jump / Split-like behavior(과도한 수 증가 금지)  
Drops:
- Slime Gelatin
- Herb Jelly
- Crystal Gel

### Razorvine Drakelet
Role: 빠른 사냥감  
Patterns: Dash / Tail  
Parts: Tail  
Drops:
- Drake Meat
- Tail Fillet
- Young Scale

### Twin Ogre — Boss
Role: 첫 Giant Boss  
Patterns:
- Club Slam
- Double Swing
- Charge
- Head coordination attack
- Enrage under threshold
Parts:
- Tusks / armor-like back part 후보
Drops:
- Ogre Meat
- Giant Marrow
- Twin Ogre Prime Cut
- Ogre Tusk

Boss Signature:
- Twin Ogre Prime Feast

## 3. Sunscar
### Cinderhorn
돌진형 마수
Drops:
- Ember Meat
- Fire Fat

### Basilisk
독/석화 테마
Patterns:
- Bite
- Tail
- Short petrify buildup
Parts:
- Tail
Drops:
- Basilisk Meat
- Basilisk Tail
- Purified Venom Gland
- Basilisk Scale

### Cockatrice
조류+파충류
Drops:
- Cockatrice Thigh
- Cockatrice Egg
- Golden Egg
- Feather

### Sandmaw
땅속 거대벌레
Patterns:
- Burrow
- Emerge
- Sweep
Drops:
- Sandworm Flesh
- Spice Gland
- Shell Segment

### Minotaur — Boss
Patterns:
- Axe Swing
- Heavy Slam
- Charge
- Wall Collision Stun
Parts:
- Left Horn
- Right Horn
Drops:
- Minotaur Beef
- Labyrinth Loin
- Minotaur Rib
- Horn Core
- Crimson Tenderloin

Boss Signature:
- Labyrinth Minotaur Steak
- Minotaur Rib Feast

## 4. 장기 대표 몬스터 판타지
Azure:
- Krakenling
- Shell Hydra
- Abyss Kraken

Mirefen:
- Bog Troll
- Swamp Hydra
- Mimic
- Troll King

Frostfang:
- Yeti
- Ice Wyrm
- Frost Chimera
- Frost Giant

Ashen:
- Hellhound
- Cyclops
- Magma Golem
- Inferno Chimera

## 5. Monster Rig Family
- Beast Quadruped
- Reptile/Drake
- Avian
- Blob
- Plant/Fungus
- Giant Humanoid
- Worm
- Multi-Neck
- Colossal

## 6. 부위파괴
Mesh 자체 판정 금지.
단순 invisible Hitbox 사용.

예:
- HIT_Minotaur_Body
- HIT_Minotaur_LeftHorn
- HIT_Minotaur_RightHorn

Part break:
1. HP separate
2. Visual crack
3. Break event
4. Part material reward
5. Broken mesh state

## 7. Monster Mastery
반복사냥 보상은 큰 드롭률 보정이 아니라 지식/수집 중심.

예:
Lv1 기본 정보  
Lv2 Drop 일부 공개  
Lv3 Part break hint  
Lv4 Rare ingredient hint  
Lv5 Trophy


---

# INGREDIENT & RECIPE BIBLE

## 1. Ingredient Categories
- Protein
- Produce
- Spice
- Special
- Material (비식재료)

Town Pantry Staples:
- Salt
- Oil
- Flour
- Broth
- Butter 등

Staple은 Gold sink 역할.

## 2. Recipe Discovery
- 첫 기본 재료 획득 → 기본 레시피 자동 발견 가능
- 재료 조합 보유 → Recipe Idea
- Boss Recipe → 퀘스트/보스 연계
- RNG Recipe Scroll 중심 구조 금지

## 3. Greenwood Foods
1. Hornboar Steak
2. Arcane Fat Roast
3. Mawcap Soup
4. Glutton Herb Aspic
5. Drakelet Tail Skewer
6. Monster Forest Stew
7. Marbled Hornboar Steak
8. Twin Ogre Prime Feast

## 4. Sunscar Foods
1. Cinderhorn Roast
2. Cockatrice Omelette
3. Sandmaw Pepper Skewer
4. Basilisk Tail Steak
5. Sunscar Monster Chili
6. Cinderhorn Pepper Pot
7. Minotaur Rib Feast
8. Labyrinth Minotaur Steak

## 5. Quality
Normal ×1.00  
Good ×1.10  
Great ×1.25  
Perfect ×1.50

수치는 Config.

조리 실패로 희귀 재료를 삭제하지 않는다.

## 6. Food Asset Tiers
C: Basic  
B: Standard polished  
A: Rare/High-quality  
S: Boss/Signature/Hero

S급:
- Twin Ogre Prime Feast
- Minotaur Rib Feast
- Labyrinth Minotaur Steak

## 7. 음식 UI
모든 주요 화면은 동일한 Food Render Source를 재사용:
- Inventory
- Recipe Book
- Restaurant Menu
- Order Card
- Shift Result

목록은 Render Thumbnail.
상세는 3D View 가능.


---

# COMBAT & WEAPONS

## 1. 전투 목표
본격 Souls-like가 아니라 Restaurant 게임을 위한 읽기 쉬운 Action Combat.

입력:
- Basic Attack
- Heavy Attack
- Dodge
- Interact
- Roblox 기본 Jump

Stamina 시스템 없음.

## 2. Basic Attack
기본 3-hit combo.
모바일에서도 단순.

## 3. Heavy Attack
- 느림
- 높은 stagger
- 높은 part break power

## 4. Dodge
- 위치 회피 중심
- 과도한 i-frame 의존 금지

## 5. Mobile
- light aim assist/facing correction
- PC/Mobile/Gamepad 공통 action abstraction

## 6. Weapon Classes
### Cleaver
균형형

### Great Cleaver
느림 / 높은 damage / part break

### Hunting Spear
긴 reach / 안전성

원거리 활 계열은 post-launch 후보.

## 7. Tier
초기:
- Starter
- Hunter
- Sunscar

Infinite enhancement는 모델 수 증가로 구현하지 않는다.

## 8. Enhancement Transfer
새 장비 획득 시 기존 강화레벨 이전 가능.

예:
Hunter Cleaver +147
→ Frost Cleaver +147

비용:
- Gold
- 지역 재료

## 9. Infinite Enhancement + Soft Power Cap
강화 숫자는 무한.
실전 능력 증가율은 점차 감소.

구간 철학:
- +1~50: 강한 체감
- +51~100: 중간
- +101~200: 완만
- +201+: 매우 완만 + prestige

정확한 공식 Config.

## 10. Visual Milestone
+10 / +25 / +50 / +100 / +200 등에서:
- material accent
- rune
- aura
- attachment
- server/local announcement 후보


---

# RESTAURANT SYSTEM

## 1. 핵심
Restaurant는 별도 Place의 1~4인 Reserved Server.

수익 조건:
- Host가 Restaurant Place에 존재
- Restaurant가 OPEN
- 실제 재료 존재
- 실제 메뉴 존재
- 직원/플레이어가 주문 처리

사냥 중/오프라인 수익 없음.

## 2. State
CLOSED
→ OPEN
→ CLOSING
→ CLOSED

OPEN:
- 신규 고객
- 주문
- 조리
- 서빙
- 매출

CLOSING:
- 신규 고객 중단
- 기존 주문 마무리
- 정산

## 3. Shift
고정 시간 제한 없음.
기준 목표 7~15분.

Dinner Rush 가능.
Shift 실패 조건 없음.
놓친 주문은 기회손실.

## 4. Host / Helper
Host:
- 식당 소유자
- Gold 소비
- Menu
- Staff
- Expansion
- CLOSE

Helper:
가능:
- Cook
- Serve
- Carry
- Order support

금지:
- Gold spend
- Fire staff
- Recruit
- Enhance
- Sell furniture
- Change menu
- Force close

## 5. Helper Reward
기여 행동 기반 `Helper Tip`.
Host 수익에 비례한 무제한 보상 금지.

목표 효율:
- 자기 식당 시간당 성장의 약 50% 이하

Helper는 Host Restaurant Renown 획득 불가.

## 6. Host Disconnect
Host reconnect grace: 기준 120초(Config).

Host 복귀:
- Resume

미복귀:
- Spawn 중단
- 자동 LAST ORDER
- Safe settlement
- Party return

## 7. Restaurant Level
Renown XP 전용.
상한 없음.

Renown Source:
- Completed orders
- Satisfaction
- Great/Perfect
- New recipe
- VIP
- Signature/Boss dish

Restaurant Level 자체가 직접 무한 매출 배율을 주지 않음.

## 8. Level Reward
매 레벨:
- Expansion Point +1

주기적:
- 시설
- Floor Permit
- Customer Tier
- Staff slot
- Storage
- Decoration capacity

기준:
- 10 level: Floor Permit
- 25: major visual/functional milestone
- 50: prestige milestone
Config화.

## 9. Capacity vs Demand
Floors = Capacity
Demand = 실제 고객 수

Demand 증가 요소:
- Renown
- Menu attractiveness
- Quality
- Customer reputation
- Market Demand

빈 층을 건설한다고 고객이 자동 생성되지 않는다.

## 10. Infinite Floors
소유 가능 층은 계속 증가.

Operating Floor Capacity 별도.
동시에 OPEN 가능한 층은 경영 능력에 따라 증가.

### Focus Floor
실제 NPC Full Simulation.

### Background Open Floor
실제 NPC 생성 없이 수치 처리.
단 실제:
- Staff
- Menu
- Ingredients
- Demand
필수.

CLOSED 또는 World 이동 시 즉시 0.

## 11. Building
Modular Build + Free Decoration.

구조:
- Floor shape module
- Kitchen zone
- dining space
- wall/floor/theme

자유배치:
- tables
- chairs
- lamps
- decor
- trophy
- rugs
- wall art


---

# STAFF SYSTEM

## 1. 철학
높은 등급은 확실히 더 좋다.
저등급을 억지로 종결까지 동일 가치로 유지하지 않는다.

Rarity:
- Common
- Rare
- Epic
- Legendary
- Mythic

기준 성능 배율(초기 테스트):
1.00 / 1.15 / 1.35 / 1.60 / 1.90

Config.

## 2. Launch Roles
### Chef
- Cook speed
- Quality
- Specialty

### Server
- Movement
- Carry count
- Service speed

Post-launch:
- Host
- Manager
- Prep Cook
- Gatherer/Hunter support 등

## 3. Recruitment Contract
Gold 전용.
Robux→Gold 직접 판매 금지.

Contract 사용:
- 후보 3명 등장
- 1명 선택
- 나머지는 떠남

단순 1회 카드 슬롯머신보다 경영 선택 제공.

## 4. 초기 Rarity 후보
Common 55%
Rare 27%
Epic 12%
Legendary 5%
Mythic 1%

단, 3슬롯 Contract 전체 확률/상위 Contract는 별도 Config.

## 5. First Staff
첫 직원은 RNG 금지.
튜토리얼 이후 `Rare Server` 확정 지급.

## 6. Recruitment Reputation / Pity
모집 반복 시 visible progression.
특정 단계:
- Rare+
- Epic+
- Legendary+
등 보장.

Mythic 획득 시 일부 reset 가능.

## 7. Level
직원은 Shift에서 실제 업무를 하며 XP 획득.

같은 레벨 기준:
Mythic > Legendary > Epic > Rare > Common

오래 키운 저등급이 방금 획득한 Lv1 상위등급보다 잠시 강할 수 있음.

## 8. Training Inheritance
퇴직/교체 시 일부 XP를 Training Manual 등으로 반환.
새 고등급 직원으로 성장 일부 이전 가능.

## 9. Wage
CLOSED: 0
Hunting: 0
Shift 배치 시에만 wage 발생.

목표:
총 매출의 대략 5~12% 범위.
실제 수치 Config.

직원 고용이 성장 보상이면서 동시에 장기 Gold sink가 되게 한다.


---

# ENHANCEMENT & ECONOMY

## 1. Currency
Spendable:
- Gold

Progress:
- Renown XP

Robux로 Gold 직접 판매하지 않는다.

## 2. Gold Sources
Primary:
- Restaurant dish sales

Secondary:
- Quest/contract
- low-value material sale 후보

Monster direct Gold drop 없음.

## 3. Gold Sinks
- Restaurant construction
- Staff recruitment
- Staff training
- Staff wage
- Weapon enhancement
- Cookware enhancement
- Pantry staples
- Decoration

Punitive sink 금지:
- durability repair tax
- ingredient spoilage
- death gold loss
- mandatory restaurant tax

## 4. Shift Economy 목표
기준 10분 Shift 순수익 테스트 범위:
- first hour: 170~250G
- ~5h: 550~950G
- ~20h: 2,400~4,000G
- ~100h: 15,000~28,000G
- ~500h: 100,000G+

최종값 아님. Config/A-B test 대상.

## 5. 음식 가격 예시
Greenwood:
- Hornboar Steak 24G
- Mawcap Soup 28G
- Drakelet Tail Skewer 38G
- Marbled Hornboar Steak 65G
- Twin Ogre Prime Feast 140G

Sunscar:
- Cinderhorn Roast 60G
- Cockatrice Omelette 70G
- Basilisk Tail Steak 110G
- Minotaur Rib 160G
- Labyrinth Minotaur Steak 220G
- Crimson Tenderloin Feast 320G

## 6. Enhancement Failure
아이템 파괴 없음.
-2 없음.

결과:
- Success
- Maintain
- -1

+10 단위 Stabilization 가능.
안정화 아래로 하락 불가.

## 7. 성공률 철학
- +0~10: 100%
- +11~20: easy
- +21~30: tension begins
- +31~50: low
- +51~100: very low
- +101+: down to minimum around 1% possible

정확한 공식 Config.

## 8. Protection
Protection Stone:
- 다음 실패 시 유지

Catalyst:
- 성공률 증가

Enhancement Focus:
- 실패할수록 성공률 누적 증가

Hard Pity:
- 최악의 실패 횟수 제한
- 일정 횟수 이후 성공 보장

Robux와 직접 연결하지 않는다.

## 9. Cost
Gold + 지역/보스 재료.

경제 목표:
평균 Shift 1회 후:
- 초반 3~5 attempts
- 중반 2~4
- 후반 고강 1~3

## 10. Cookware Infinite Enhancement
무한 강화.
조리속도는 무한 상승 금지.

Soft Cap 이후 가치:
- quality stability
- concurrent capacity
- category efficiency
- Perfect assistance
- prestige

## 11. Restaurant Construction
Renown = 건설 자격
Gold = 실제 건설 비용

예:
Lv10 → 2F Permit
이후 Gold 지불하여 실제 건설.


---

# UI / UX

## 1. 철학
Mobile-first.
게임 화면이 UI보다 더 많이 보여야 한다.

톤:
- 밝은 목재
- 크림
- 금색
- 선명한 음식 이미지

## 2. World HUD
- HP
- Gold
- World Blessing
- 간단 Goal
- Equipment/Quick material
- Party shortcut

Mobile combat:
- Attack
- Heavy
- Dodge
- Interact
- 기본 Jump

## 3. Combat
보여줄 것:
- Monster HP
- Part break state
- Telegraph

숫자 남발 금지.

## 4. Rare Drop
중앙 짧은 Reveal:
- RARE INGREDIENT
- BOSS MATERIAL

1초 내외.

## 5. Monster Book
- 3D preview
- Threat
- Habitat
- Part
- Ingredient discovery
- Recipe discovery
- Mastery

Unknown = `???`

## 6. Recipe Book
음식 비주얼이 가장 큼.
- Ingredients
- Tool
- Base price
- Best quality

Food Render Thumbnail 재사용.

## 7. Inventory
Tabs:
- Ingredients
- Materials
- Equipment

Ingredient detail:
- owned count
- recipes using it

## 8. Party
최대 4.
Party leader 이동 제안:
- JOIN
- STAY

강제 텔레포트 금지.

## 9. Restaurant Prep
표시:
- Menu
- Staff
- Party
- Ingredients
- Floor

ENTER RESTAURANT

## 10. Restaurant Place
입장 기본 CLOSED.

OPEN RESTAURANT 버튼.
Confirm:
- Menu count
- Staff
- Active floors

## 11. Restaurant HUD
- Shift duration
- Revenue
- Orders
- Stock alert
- LAST ORDER

Order cards는 최대 급한 4~5개만 HUD.
전체는 View All.

## 12. Cooking
주문 있는 음식 우선.
짧은 Mini-game.
Steak 예:
- Flip
- Serve

Quality result:
Normal / Good / Great / Perfect

Perfect:
0.7~1초 Hero Food Shot.

## 13. Floor UI
예:
1F Busy
2F Normal
3F Needs Staff
4F Closed

## 14. Settlement
SHIFT COMPLETE

- Revenue
- Staff Wages
- Profit
- Customers
- Perfect count
- Renown
- Best Seller
- Best Dish
- Staff XP
- Restaurant Level progress

그 다음:
- Upgrade Equipment
- Recruit Staff
- Expand Restaurant
- Return World

## 15. Enhancement UI
반드시 실제 확률 공개:
- Success
- Maintain
- -1
- Checkpoint
- Focus/Pity
- Protection state
- Cost

## 16. Recruitment UI
세 후보를 한 화면에서 비교.
Rarity / Role / Stats / Trait.

Legendary/Mythic은 짧고 강한 연출.
스킵 불가능 장시간 연출 금지.

## 17. FTUE 5분
0:00 Dragon dream dialogue
0:30 Hornboar
1:30 Meat
2:00 Training Kitchen
3:00 Hornboar Steak
3:30 NPC order
4:00 Serve
4:15 First Gold
4:30 YOUR RESTAURANT IS READY

긴 텍스트 튜토리얼 금지.
월드 표시/아이콘/버튼 Pulse 사용.


---

# MONETIZATION

## 1. 철학
첫 목표는 Retention.
BM이 Core Loop를 대체하지 않는다.

Gold 직접 판매 금지.

## 2. Launch BM
### World Blessings — Developer Products
Tailwind:
- 서버 전체 비전투 이동속도

Hunter's Rhythm:
- 서버 전체 공격속도
- 최종 공격속도 상한 준수

Bounty Blessing:
- 서버 전체 확정 기본 식재료 획득량 증가

동일 Blessing:
- 배율 중첩 금지
- 지속시간 연장

서로 다른 Blessing은 동시 가능.

## 3. Blessing Token
구매 즉시 강제 발동하지 않고 Token 지급 가능.
Hearthcross Shrine에서 원하는 시점에 Activation.

구매자가 Restaurant로 바로 이동해 버프를 낭비하는 문제 방지.

## 4. Social Presentation
Activation:
- Bell
- server announcement
- shrine/light/banner effect
- buyer attribution

구매자가 서버 기여자로 보이게 한다.

## 5. Fortune Blessing
희귀 드롭률 ×1.5는 후속 후보.

Robux가 랜덤 확률에 영향을 주므로:
- 실제 기본 확률 표시
- 변경 확률 표시
- PolicyService 제한 처리
- 관련 규정 대응

출시 필수 아님.

## 6. Cosmetics
- Restaurant theme
- Sign
- Furniture skin
- Weapon skin
- Chef outfit
- Emote
- Layout preset

## 7. 초기 제외 BM
- Gold 판매
- Mythic Staff 직접 판매
- +100 Weapon 판매
- 강화 성공률 대폭 증가
- Rare ingredient 직접 판매
- 개인 공격력 큰 배율
- Staff gacha with Robux

## 8. Pet
Post-launch.
초기 구현 금지.


---

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


---

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


---

# ASSET PRODUCTION BIBLE

## 1. 우선순위
S:
- Hornboar
- Twin Ogre
- Minotaur
- Boss food
- Restaurant facade
- Hearthcross center
- representative weapons

A:
- normal monsters
- normal foods
- cookware
- main buildings
- kitchen

B:
- environment kits
- repeat props

## 2. Hearthcross
- Central Hearth
- Expedition Gate
- Restaurant Facade
- Hunter Guild
- Recruitment Hall
- Blacksmith
- Kitchen Workshop
- Training Kitchen
- General Store
- Ranking Plaza

Architecture Kit:
- wall
- wood wall
- column
- window
- door
- roof
- balcony
- sign
- stair
- fence
- lamp

## 3. Greenwood Kit
Vegetation:
- large tree 4
- small tree 3
- bush 3
- grass 4
- flower 3
- fantasy mushroom 4

Terrain:
- rock 6
- cliff 4
- small rock 4
- root 3
- creek
- waterfall

POI:
- Hunter Camp
- Ruins
- Mawcap Grove
- Drake Nest
- Twin Ogre Ruins

## 4. Sunscar Kit
- canyon cliff 5
- red rock 6
- stone pillar 3
- fantasy cactus 4
- pepper plant
- dry grass
- glowing ore 3
- labyrinth wall
- labyrinth pillar
- stone gate
- wood bridge
- caravan camp
- Minotaur Arena

## 5. Monster Assets
10 launch monsters:
Hornboar
Mawcap
Glutton Slime
Razorvine Drakelet
Twin Ogre
Cinderhorn
Basilisk
Cockatrice
Sandmaw
Minotaur

## 6. Animation
Normal target:
- Idle
- Walk/Run
- Attack A
- Attack B
- Hit
- Stagger
- Despawn/Death
- 1~2 special as needed

Boss target:
~12 animations including special/enrage/part break reaction.

## 7. Food Assets
Greenwood 8
Sunscar 8

S-grade:
- Twin Ogre Prime Feast
- Minotaur Rib Feast
- Labyrinth Minotaur Steak

Quality variation:
Base mesh + modular garnish/sauce/vfx.

## 8. Weapons
3 classes × initial 3 visual tiers ≈ 9 models.

## 9. Cookware
Pan / Grill / Pot
각 3 visual tiers ≈ 9 variants.

## 10. Restaurant Furniture
초기 30~40개:
tables
chairs
counter
kitchen station
storage
lamps
wall decor
plants
rug
shelf
trophy frame

## 11. Staff/Customers
R15 기반.
Rarity를 새 Mesh 전체로 표현하지 않는다.

Chef outfit
Server outfit

Customer archetype:
- Villager
- Hunter
- Traveler
- Merchant
- Gourmet/Noble

## 12. VFX
- Rare Drop
- Boss Drop
- Recipe Discovery
- Perfect Cook
- Restaurant OPEN
- Dinner Rush
- Enhance Success
- Enhance Fail
- Enhance Milestone
- Legendary Staff
- Mythic Staff
- Blessing x3
- Part Break

## 13. Audio
Music:
- Hearthcross
- Greenwood
- Sunscar
- Restaurant

Rush:
Restaurant track + percussion layer.

Core SFX:
30+ 목표.

## 14. Naming
MON_Hornboar
MON_TwinOgre
MON_Minotaur
ENV_Greenwood_Tree_A
BLD_Hearthcross_Blacksmith
FOOD_HornboarSteak
FOOD_TwinOgrePrimeFeast
WPN_Cleaver_Hunter
COOK_Grill_Hunter
VFX_PerfectCook
SFX_EnhanceSuccess
PART_Minotaur_LeftHorn
HIT_Minotaur_LeftHorn

## 15. Production Waves
Wave 0: Greybox
Wave 1: Vertical Slice final art
Wave 2: Greenwood complete
Wave 3: Sunscar
Wave 4: cosmetics/polish


---

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


---

# CODEX RULES

이 문서는 구현 규칙이다. 위반하지 않는다.

## 1. 범위
요청된 기능만 구현한다.
대규모 신규 시스템 임의 추가 금지.

## 2. main
`main` 직접 수정 금지.
Feature branch에서 작업.

## 3. Docs
작업 전 반드시:
- MASTER_GDD
- CODEX_RULES
- TECH_ARCHITECTURE
- DATA_SCHEMA
- 관련 Bible
읽기.

## 4. Server Authority
클라이언트 값을 신뢰하지 않는다.

Server authoritative:
- Damage
- Drops
- Inventory
- Gold
- Renown
- Cooking consumption
- Sale
- Recruitment
- Enhancement
- Session settlement
- Blessings

## 5. Config
밸런스 숫자를 서비스 코드에 하드코딩하지 않는다.
Config 사용.

테스트 임시값:
`TODO_BALANCE` 주석.

## 6. Data
SchemaVersion 필수.
Migration 준비.
기존 데이터 파괴 변경 금지.

## 7. Session
Restaurant 경제 처리는 SessionId 기반.
Settlement는 idempotent.
Pantry escrow 필수.

## 8. 모바일
모바일에서 사용할 수 없는 기능은 완료로 간주하지 않는다.

PC/Touch/Gamepad input abstraction.

## 9. UI
화면 전체를 UI로 덮지 않는다.
Mobile safe area 고려.
기능 해금 전 복잡한 UI 노출 금지.

## 10. Performance
- 모든 NPC Humanoid 사용 금지
- unnecessary pathfinding 금지
- reusable mesh/package
- streaming 고려
- monster budget
- restaurant focus/background simulation

## 11. 기존 파일
기존 시스템을 이유 없이 삭제/대체하지 않는다.
공통 API 변경 시 관련 브랜치 영향 기록.

## 12. 테스트
각 작업 완료 시:
- unit-like logic tests 가능 범위
- server/client test
- mobile emulator
- edge cases
- reconnect/failure cases
를 보고.

## 13. 완료 보고 형식
반드시:
1. 구현 내용
2. 변경 파일
3. 테스트 결과
4. 실패/미검증 항목
5. TODO
6. 다른 브랜치 영향
을 보고.

## 14. 숨기지 말 것
컴파일/런타임 실패, 미검증, TODO를 숨기지 않는다.

## 15. Art placeholders
최종 모델을 기다리며 로직 개발을 막지 않는다.
`*_PLACEHOLDER` Greybox 사용.
Package 교체 가능한 구조 유지.


---

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
