# The Last Recipe — Codex Design Pack

버전: Design Lock 1.1

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


## Design Lock 1.1 문서 소스
- [첨부 통합 설계 원본](../The_Last_Recipe_ALL_IN_ONE_CODEX_SPEC.md): 업로드된 v1.1 파일을 원본 그대로 보관한다. 이 폴더의 설계 문서는 대응하는 19개 최상위 섹션과 같은 내용을 담는다.
- [Phase 0.8 작업 지시 원본](../NEXT_CODEX_INSTRUCTION_Phase_0_8.md): 사용자 첨부 원본을 그대로 보관한다.
- [Design Lock 1.0 보관본](../archive/design-lock-1.0/The_Last_Recipe_ALL_IN_ONE_CODEX_SPEC.md): 이전 통합본과 내용이 변경된 분리 문서, README, manifest를 보존한다.

## 다음 작업: Phase 0.8
`PARTY_EXPEDITION.md`를 추가했다. 기존 Foundation을 유지하면서 Compact Party HUD, 같은 Hearthcross 서버의 Public Party Finder, Private Invite, ReadyCheck UX, ExpeditionSession 계약을 추가한다. Cross-server Quick Match는 인터페이스와 Config hook만 준비한다.

작업 전 읽기 순서:
1. `CODEX_START_HERE.md`
2. `MASTER_GDD.md`
3. `PARTY_EXPEDITION.md`
4. `UI_UX.md`
5. `DATA_SCHEMA.md`
6. `TECH_ARCHITECTURE.md`
7. `CODEX_RULES.md`
8. `IMPLEMENTATION_PLAN.md`

첨부 작업 지시의 “Foundation Studio QA는 통과했다”는 사용자 제공 전제이며, 이번 환경에서 실행한 QA 결과를 뜻하지 않는다. 실제 검증 결과와 미검증 항목은 구현 보고에서 별도로 기록한다.
