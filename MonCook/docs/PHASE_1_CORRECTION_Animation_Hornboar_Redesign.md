# PHASE 1 CORRECTION — Combat Animation & Hornboar V1 Redesign

현재 Studio에서 실제 플레이를 확인했다.

기능보다 먼저 수정해야 할 중요한 문제가 있다.

이번 수정이 끝나기 전에는 Phase 1을 완료 처리하지 않는다.

---

## 1. Player 공격 애니메이션이 없음

현재 Roblox 캐릭터가 무기를 들고 공격해도 실제 타격 모션이 충분히 보이지 않는다.

Starter Cleaver 전용 공격 Animation을 추가한다.

최소 필요:

### Basic Combo 1
- 오른쪽 → 왼쪽 횡베기
- 짧은 windup
- 명확한 swing
- recover

### Basic Combo 2
- 반대 방향 또는 대각선 베기

### Basic Combo 3
- 더 강한 마무리 공격
- 오버헤드 또는 강한 내려베기

### Heavy Attack
- Basic보다 확실히 긴 windup
- 양손/몸 전체를 사용하는 느낌
- 강한 내려베기 또는 큰 횡베기
- PartBreakPower가 높은 공격이라는 것이 애니메이션에서도 보여야 함

캐릭터의 팔만 약간 움직이는 수준으로 끝내지 않는다.

몸통 회전과 상체 무게 이동을 포함해
“무기를 휘두르고 있다”는 것이 명확해야 한다.

---

## 2. Animation Marker와 Damage Window 연결

공격 입력 즉시 Damage를 주지 않는다.

Animation 안에 예:

```text
Windup
→ HitStart
→ Hit
→ HitEnd
→ Recover
```

와 같은 Marker 또는 명확한 Attack Window를 둔다.

실제 서버 Damage 판정 시간과
캐릭터의 Cleaver가 몬스터를 통과하는 순간이 최대한 일치해야 한다.

Server authoritative 구조는 유지한다.

Client Animation 자체가 Damage를 결정해서는 안 된다.

---

## 3. Hornboar 피격 Animation 추가

현재 Hornboar가 맞아도 거의 반응이 없다.

최소:

- LightHit
- HeavyHit / Stagger
- HornHit reaction
- HornBreak reaction
- Death

를 추가한다.

### Light Hit

일반 공격을 맞으면:

- 몸이 짧게 뒤틀림
- 머리가 반대쪽으로 젖혀짐
- 짧은 flinch

전투 흐름을 과도하게 끊지 않는다.

### Heavy Hit

Heavy Attack:

- 더 큰 recoil
- 짧은 stagger
- 몸 전체가 밀리는 느낌

### Horn Hit

뿔을 타격했을 때는
일반 Body Hit과 약간 다른 머리 반응이 있어야 한다.

### Horn Break

뿔 파괴 순간:

- 머리를 크게 젖힘
- 짧은 stagger
- Horn break VFX
- Intact Horn → Broken Horn
- Horn Core 획득 연출

이 순서가 한눈에 보여야 한다.

---

## 4. Hit Feedback

공격이 맞았다는 감각을 Animation에만 의존하지 않는다.

최소한:

- 짧은 hit spark
- monster recoil
- 작은 hit sound
- Heavy는 일반 공격보다 강한 effect
- Horn hit은 별도 effect 가능

과도한 화면 흔들림은 금지.

고어/피 표현도 금지.

---

# 5. 현재 Hornboar 외형 폐기 또는 대폭 재작업

현재 보이는 구형 위주의 Monster Model은
최종 `MON_Hornboar_V1`로 승인하지 않는다.

현재 모델은 Prototype/Placeholder 수준이다.

Hornboar는 다시 디자인한다.

---

# 6. Hornboar 핵심 실루엣

한눈에:

> “판타지 뿔 멧돼지”

로 보여야 한다.

반드시 다음 형태가 읽혀야 한다.

### Body

- 가로로 긴 멧돼지 몸통
- 낮은 무게중심
- 튼튼한 네 다리
- 큰 어깨
- 뒤쪽은 어깨보다 약간 낮음
- 현재처럼 거의 완전한 구체 형태 금지

### Head

- 몸보다 작지만 묵직한 머리
- 앞으로 튀어나온 멧돼지 주둥이
- 작은 귀
- 낮게 깔린 공격적인 눈

현재처럼 머리가 거대한 공처럼 보이면 안 된다.

### Legs

반드시 네 다리가 명확하게 보여야 한다.

현재처럼 몸 아래에 작은 구체가 붙은 형태 금지.

형태:

```text
Upper Leg
→ Lower Leg
→ Hoof
```

까지 단순화된 Low Poly로 표현.

---

# 7. Horn Design

Hornboar의 Hero Feature.

멀리서도 보여야 한다.

권장:

- 이마에서 앞으로 솟는 큰 판타지 뿔
- 뒤에서 앞으로 약간 휘어짐
- 뿌리가 두껍고 끝으로 갈수록 가늘어짐

추가로 작은 멧돼지 tusk는 가능.

하지만:

> 일반 멧돼지 tusk만 있고 판타지 Horn이 안 보이는 디자인

은 금지한다.

Horn은 Medium 거리에서도 식별 가능해야 한다.

---

# 8. Broken Horn

반드시 별도 상태 존재.

예:

```text
Horn_Intact
Horn_Broken
```

파괴 후에는 완전히 아무것도 없는 것보다
짧은 stump가 남는 형태가 좋다.

게임플레이 Hitbox와 Visual은 분리한다.

---

# 9. Color / Material

기존 Art Direction 유지:

### Body
- warm dark brown
- reddish brown
- 일부 lighter fur

### Snout
- 약간 밝은 갈색

### Horn
- ivory / bone
- 매우 약한 magical accent 가능

### Eyes
- 판타지 cyan/amber accent 가능

하지만 Neon이 지나치게 강해서 장난감처럼 보이지 않게 한다.

---

# 10. Modeling Quality

Hornboar는 Sphere/Part 조합 Prototype에서 끝내지 않는다.

Blender를 실제 사용할 수 있으므로
**Blender 기반 Stylized Low-Poly Mesh V1을 제작한다.**

목표:

```text
3,000 ~ 6,000 triangles
```

권장 workflow:

```text
Blockout
→ silhouette check
→ low-poly modeling
→ rig
→ animation
→ export
→ Roblox Studio verification
```

Blender Python 자동화는 보조 수단으로 사용할 수 있지만,
script 생성만 하고 완료 처리하면 안 된다.

실제 Mesh 결과를 확인한다.

---

# 11. Hornboar 크기

Roblox Avatar와 같이 놓고 비율을 확인한다.

일반 플레이어보다:

- 몸통은 확실히 큼
- 어깨 높이는 위협적으로 보임
- 지나치게 거대하지 않음

첫 사냥 몬스터이므로 Boss처럼 커서는 안 된다.

대략적인 인상:

```text
Player
  O
 /|\
 / \

       ____Hornboar____
   ___/                \__
  /                       \
 /                         \
```

“작은 돼지”가 아니라
“사냥해야 하는 야생 판타지 몬스터”의 느낌.

---

# 12. Animation Set 보강

Hornboar:

- Idle
- Walk
- Run
- Alert
- ChargeWindup
- Charge
- Headbutt
- LightHit
- HeavyHit
- HornHit
- HornBreak
- Stagger
- Death

최소 Studio 시연에서 다음은 반드시 구분되어야 한다:

```text
Idle
Run
ChargeWindup
Charge
Attack
Hit
HornBreak
Death
```

---

# 13. Charge Readability

Charge는 특히 중요하다.

흐름:

```text
플레이어 발견
↓
멈춤
↓
머리 낮춤
↓
발 또는 몸으로 준비 동작
↓
Charge Windup
↓
돌진
↓
Miss / Hit
↓
Recover
```

플레이어가 보고 피할 수 있어야 한다.

갑자기 미끄러지듯 이동하면 안 된다.

---

# 14. Death

HP 0:

- 즉시 굳어서 사라지는 방식 금지
- 짧은 Death Animation
- 밝은 판타지 dissolve / particles
- 이후 loot presentation

고어 표현 없음.

---

# 15. 테스트

Studio에서 반드시 직접 확인:

### Player

1. Basic1 animation
2. Basic2 animation
3. Basic3 animation
4. Heavy animation
5. Dodge animation
6. Animation과 hit timing 일치

### Hornboar

7. 멀리서 Hornboar로 보이는가
8. 네 다리가 명확한가
9. 주둥이가 보이는가
10. Horn이 명확한가
11. Light hit reaction
12. Heavy stagger
13. Horn hit reaction
14. Horn break animation
15. Broken horn visual
16. Charge windup
17. Charge
18. Death

---

# 16. 기존 시스템 유지

이번 수정 때문에 다음을 깨뜨리지 않는다.

- Personal Loot
- Contribution
- Horn Core 1회 지급
- Kill ingredient reward
- Inventory
- Respawn
- Multiplayer
- Server authority
- Phase 0 Party/Foundation

---

# 완료 조건

Phase 1의 V1 Art를 다음 기준으로 다시 판정한다.

> 플레이어가 실제로 Cleaver를 휘두르는 것이 보이고,
> Hornboar가 맞았을 때 반응하며,
> Hornboar의 외형을 처음 보는 사람이
> 설명 없이도 “판타지 멧돼지 몬스터”라고 인식할 수 있다.

현재 Sphere 중심의 Monster Model을 그대로 사용한 상태에서는 Phase 1을 완료하지 않는다.

수정 완료 후 새 Studio `.rbxlx`를 제공하고 작업을 멈춘다.

전체 소스 PC 설치 ZIP은 만들지 않는다.