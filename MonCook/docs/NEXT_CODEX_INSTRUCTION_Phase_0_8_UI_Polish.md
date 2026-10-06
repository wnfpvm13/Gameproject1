# NEXT CODEX INSTRUCTION — Phase 0.8 UI Polish

사용자 지시(2026-10-06). Phase 0.8 파티 기능의 Studio 정상 동작은 사용자가 확인했다. 이번 작업은 기존 Party / Finder / ReadyCheck / Expedition 로직을 변경하지 않고 UI/UX만 다듬는다. 기존 141개 테스트 그룹을 유지한다.

먼저 CODEX_START_HERE, MASTER_GDD, PARTY_EXPEDITION, UI_UX, CODEX_RULES, IMPLEMENTATION_STATUS를 읽는다.

## UI 요구사항

1. Finder: 정보를 왼쪽/중앙에 배치하고 모집 중 상태 오른쪽에 참가 버튼을 둔다. 전체 너비의 큰 하단 버튼을 제거하고 카드 높이를 줄인다. 모바일 최소 터치 크기를 유지한다.
2. 색상: Roblox 채팅창처럼 반투명, 다른 UI보다 조금 진한 웜브라운/웜그레이. 완전 검정은 금지하며 밝은 텍스트와 따뜻한 브라운/골드 포인트를 유지한다. 색 값은 Theme Config 또는 Style 상수로 분리한다.
3. 버튼: 재사용 가능한 Normal / Hover / Pressed / Disabled 상태. Hover는 밝아지고 Pressed는 진해지며 Disabled는 채도/투명도를 줄인다. 과도한 애니메이션은 금지한다.
4. 드래그: PC/Touch에서 상단이나 별도 손잡이를 잡아 이동한다. 버튼 클릭과 충돌하지 않으며 Safe Area에 clamp하고 화면 크기 변경 시 보정한다. 기본은 우측 상단. 영구 저장은 필수가 아니며 후속 저장 가능한 위치 구조를 분리한다.
5. Collapsed: 가로형을 세로 스택형으로 바꾼다. 최소 가로폭, 모바일 세로 우선, 최대 4명, 얼굴·공간이 있으면 이름·리더 왕관. 다시 펼치기 버튼을 명확히 둔다.
6. Expanded: 과도하게 큰 패널을 피하고 멤버·Leader·Public/Private·Activity/Target·Ready·Invite·Leave·Finder를 표시한다. 불필요한 설명을 최소화한다.
7. ReadyCheck: ✓ 함께 이동 / … 응답 중 / — 이번엔 남음과 `3 / 4명 이동 준비`. 아이콘과 텍스트를 함께 사용하며 기존 동의 계약은 유지한다.
8. Chat/PlayerList/TopBar/Menu/모바일 Safe Area 겹침을 점검한다. 일반 PC·작은 창·모바일 세로/가로에서 확인하고 좁은 화면에 compact·세로 stack·최소 width를 적용한다.
9. 기존 Foundation Party ID 입력/테스트 Debug UI를 유지한다. Studio AND Testing.ShowFoundationDebugUI == true에서만 표시하며 기본 false. Release UI와 독립적으로 둔다.

## 변경 금지

PartyService 핵심, Public/Private, Finder 서버 로직, ReadyCheck 계약, ExpeditionSession 상태, FakeTeleport, Restaurant Session, DataService, 경제/저장 계약. UI Presentation layer만 확장한다.

## 검증·종료

기존 141개 그룹을 유지한다. 추가 검증은 vertical layout, drag/resize clamp, Debug gating, compact Finder 계산, hover/pressed style mapping, 좁은 모바일 배치다.

실제 Studio 수동 확인: Finder 참가 위치, Hover/Pressed 색, 반투명 배경, PC/Touch 드래그, 세로 축소, 모바일 세로/가로, Chat/PlayerList 겹침.

CODEX_RULES의 6항목(구현, 파일, 테스트, 실제 Studio 미검증, TODO, 다른 브랜치 영향)으로 보고한다. 새로운 게임 시스템에 넘어가지 않고 Phase 0.8 UI Polish에서 멈춘다.
