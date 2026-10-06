# NEXT CODEX INSTRUCTION — Phase 0.8 Party UX & Expedition Foundation

현재 `feature/moncook-foundation`의 Foundation Studio QA는 통과했다.

기존 저장/파티/세션/텔레포트 골격은 유지한다.
이번 작업은 Foundation을 갈아엎는 것이 아니라 실제 플레이용 Party UX와 Expedition 추상화를 추가한다.

## 반드시 먼저 읽기
- CODEX_START_HERE.md
- MASTER_GDD.md
- PARTY_EXPEDITION.md
- UI_UX.md
- DATA_SCHEMA.md
- TECH_ARCHITECTURE.md
- CODEX_RULES.md
- IMPLEMENTATION_PLAN.md

## 요구사항

### 1. 기존 Foundation Debug UI 격리
Party ID 입력과 테스트용 큰 패널은 삭제하지 않는다.
다만 아래 조건에서만 보인다.
- Studio
- `Testing.ShowFoundationDebugUI == true`

Release Party UI에서는 PartyId 직접 입력을 요구하지 않는다.

### 2. Compact Party HUD
- 우측 상단 Safe Area 아래
- 채팅/Core UI와 겹치지 않게
- 프로필 얼굴 + 짧은 이름
- Leader crown
- collapse/expand
- mobile responsive
- PC/Touch/Gamepad Activated

Collapsed:
- 얼굴 + 이름

Expanded:
- 멤버
- 공개/비공개
- Activity/Target
- 준비상태
- 초대/탈퇴
- Party Finder

### 3. ReadyCheck UX
기존 Proposal/Response 내부 로직은 재사용 가능.

실제 표시:
- 함께 이동
- 응답 중
- 이번엔 남음
- `3/4명 이동 준비`

### 4. Public / Private Party
Runtime Party에 Visibility 추가.
- Public
- Private

Private는 Finder에 표시 금지.

### 5. Party Finder V1
현재 Hearthcross 서버 안에서만 동작.

목록:
- Activity
- Target
- Host
- Members / 4
- Join

Party ID 없이 참가 가능.

### 6. Expedition Contract
전체 사냥 콘텐츠는 아직 만들지 않는다.

골격:
- ExpeditionSession
- state machine
- Region/Target
- selected party members
- Restaurant transport abstraction 재사용
- FakeTeleport test

Result destinations:
- Repeat
- HostRestaurant
- Hearthcross

### 7. Quick Match
이번 작업에서 Cross-server MemoryStoreQueue 실구현 금지.
인터페이스/Config hook/TODO만 준비.

### 8. Regression
기존 Foundation 테스트는 계속 통과해야 한다.

추가 테스트:
- Public finder join
- Private hidden
- full party
- visibility change
- ready state
- debug UI gating
- ExpeditionSession lifecycle
- stale/duplicate expedition actions
- fake transport

## 완료 보고
1. 구현 내용
2. 변경 파일
3. 테스트 결과
4. 미검증
5. TODO
6. 다른 브랜치 영향
