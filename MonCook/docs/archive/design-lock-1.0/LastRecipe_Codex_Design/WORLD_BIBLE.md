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
