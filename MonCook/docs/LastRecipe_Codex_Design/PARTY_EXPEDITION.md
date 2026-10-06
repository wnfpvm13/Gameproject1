# PARTY & EXPEDITION SYSTEM

## 1. 목적
파티는 단순 친구 목록이 아니라 사냥·원정·Restaurant 협동을 연결하는 핵심 소셜 시스템이다.
기존 Foundation의 Party ID 직접 입력 UI는 실제 플레이 UX가 아니라 QA/Debug 전용으로 내린다.

## 2. Party 기본 규칙
- 최대 1~4명
- Visibility: Public / Private
- Status: Forming / ReadyCheck / InActivity / Closed
- Activity: Free / SharedHunt / Expedition / Restaurant
- TargetId: TwinOgre / Minotaur / RegionId 등
- PartyId는 내부 식별자이며 실제 플레이어 UI에서 직접 입력하지 않는다.

## 3. Public Party
Public Party는 같은 Hearthcross 서버의 Party Finder에 표시된다.

생성 시 선택:
- 목표 콘텐츠
- 공개/비공개
- 필요 시 최소/최대 인원

예:
- Greenwood Farm
- Twin Ogre Hunt
- Sunscar Expedition
- Minotaur Hunt
- Restaurant Shift

### Party Finder V1
초기 버전은 현재 Hearthcross 서버 안에서만 검색한다.

표시:
- Activity/Target
- Host
- 현재 인원 / 최대 인원
- 상태
- Join

파티 번호 공유가 없어도 참가 가능해야 한다.

## 4. Private Party
Private Party는 Party Finder에 나타나지 않는다.

참가:
- 현재 서버 플레이어 직접 초대
- 친구 초대
- SocialService 기반 외부 친구 초대는 후속 연결 가능

## 5. Quick Match
V1.5 이후 Cross-server 자동매칭.

후보 기술:
- MemoryStoreQueue
- TargetId별 Queue
- 2~4명 매칭
- Reserved Expedition Server 생성
- Teleport

초기 순서:
1. Same-server Party Finder
2. Cross-server Quick Match

Cross-server Party Browser를 먼저 만들지 않는다.

## 6. Compact Party HUD
기존 큰 Foundation 패널은 실제 HUD로 사용하지 않는다.

기본:
- 오른쪽 상단 Safe Area 아래
- 작은 프로필 얼굴
- 짧은 이름
- Leader crown
- 준비/이동 상태
- 펼치기/접기

Collapsed:
- 얼굴 + 이름

Combat Compact:
- 얼굴 아이콘 중심

Expanded:
- 목표
- 공개/비공개
- 멤버
- 준비 상태
- 초대
- Party Finder
- 탈퇴

## 7. ReadyCheck
실제 UI에서는 JOIN / STAY 직접 표기를 사용하지 않는다.

표시:
- ✓ 함께 이동
- … 응답 중
- — 이번엔 남음

요약:
`3 / 4명 이동 준비`

색뿐 아니라 아이콘 + 텍스트로 구분한다.

## 8. 사냥 콘텐츠 2계층

### Shared Hunting Field
World Place 공용 사냥지역.

목적:
- 초보자
- 일반 파밍
- 우연한 협동
- 살아 있는 월드

예: Greenwood Outskirts
- Hornboar
- Mawcap
- Glutton Slime

특징:
- Personal Loot
- 빠른 Respawn
- 일반 재료 중심
- 튜토리얼 전투는 개인화

### Expedition Instance
1~4인 Reserved Server.

목적:
- 대형 사냥터
- 정예
- 보스
- 희귀/부위 재료
- 파티 집중 플레이
- 몬스터 독식 방지

예:
Greenwood Deep Ruins
- Razorvine Drakelet
- Elite Hornboar
- Twin Ogre

Sunscar Expedition
- Cinderhorn
- Basilisk
- Cockatrice
- Sandmaw
- Minotaur

## 9. Expedition Session
상태:
Preparing → Teleporting → Active → Result → Returning → Closed

Restaurant Session과 공통 transport/session 패턴을 재사용하되 세션 타입과 경제 처리는 분리한다.

## 10. Expedition Scaling
선형 HP 배율 금지.
4명이 분명히 더 효율적이어야 한다.
혼자도 핵심 콘텐츠 완료 가능해야 한다.
정확한 값은 Config.

## 11. Personal Loot / Contribution
공용/Expedition 모두 Personal Loot.

기여:
- Damage
- Part Damage
- Encounter participation

AFK 입구 대기자는 Boss reward 없음.
초보에게 지나치게 엄격한 기여 기준은 금지.

## 12. Expedition Result Camp
종료 후 선택:
1. Repeat Expedition
2. Go to Host Restaurant
3. Return to Hearthcross

핵심 연결:
`Minotaur Hunt → Minotaur Beef → Host Restaurant → Minotaur Dish Shift`

## 13. 파티의 가치
파티 자체 큰 Drop 배율은 초기 도입하지 않는다.

장점:
- 사냥속도
- 부위파괴
- 보스 대응
- 몬스터 병렬 처리
- Restaurant 협동

## 14. Debug UI
기존 Party ID / 테스트 버튼은 삭제하지 않는다.

노출 조건:
- Studio
- Testing.ShowFoundationDebugUI = true

Release UI에서는 숨긴다.
