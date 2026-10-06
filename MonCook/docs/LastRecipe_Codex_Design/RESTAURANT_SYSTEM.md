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
