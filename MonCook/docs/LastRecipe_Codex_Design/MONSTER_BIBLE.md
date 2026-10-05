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
