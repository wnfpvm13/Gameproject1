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
