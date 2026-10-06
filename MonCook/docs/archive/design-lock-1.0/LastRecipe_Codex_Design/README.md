# The Last Recipe — Codex Design Pack

버전: Design Lock 1.0  
상태: **Codex 구현 시작 가능**  
언어: 한국어  
대상: Roblox Studio / Luau / Codex 병렬 개발

## 이 문서 세트의 목적
이 폴더는 현재까지 확정된 게임 기획을 Codex가 자의적으로 재해석하지 않고 구현하도록 하기 위한 단일 기준점(Single Source of Truth)이다.

게임의 핵심 한 문장:

> **밝은 판타지 세계에서 오우거·미노타우르스·뿔멧돼지 같은 몬스터를 사냥해 식재료를 얻고, 친구들과 직접 레스토랑을 운영하며 식당·직원·무기·조리도구를 끝없이 성장시키는 게임.**

## 반드시 먼저 읽을 문서
1. `CODEX_START_HERE.md`
2. `MASTER_GDD.md`
3. `CODEX_RULES.md`
4. `TECH_ARCHITECTURE.md`
5. `DATA_SCHEMA.md`
6. 작업할 기능에 해당하는 Bible 문서
7. `IMPLEMENTATION_PLAN.md`

## 설계상 절대 변경 금지에 가까운 핵심
- World Place: 약 20인 공용 서버
- Restaurant Place: 1~4인 Reserved Server
- 식당은 플레이어가 직접 OPEN해야만 손님/주문/매출이 발생
- 사냥 중/오프라인 자동매출 없음
- Monster Cuisine 정체성
- 밝고 따뜻한 판타지 톤
- 음식은 핵심 Hero Asset
- Restaurant Level 상한 없음
- 무기/조리도구 강화 상한 없음
- 고강은 성공률 감소, 실패 시 유지 또는 -1, 파괴 없음
- 직원은 높은 등급일수록 확실히 강함
- Gold는 플레이로 벌며 Robux로 직접 판매하지 않음
- 핵심 경제/강화/드롭/모집/정산은 서버 권한
- 모든 밸런스 수치는 Config 중심

정확한 HP, 가격, 확률, XP는 플레이테스트 대상이며 코드 하드코딩 금지.
