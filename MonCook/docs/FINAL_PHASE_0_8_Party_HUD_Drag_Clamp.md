# FINAL PHASE 0.8 FIX — Party HUD Drag Clamp

사용자 지시: 2026-10-06. 현재 HUD 기능·크기·색상·Finder·ReadyCheck·드래그는 정상이다. 이번 수정은 수동 드래그에서 Chat/PlayerList를 hard obstacle로 취급하는 제한만 해제한다.

- 초기 위치와 화면 resize의 자동 배치는 기존 Chat/PlayerList/TopBar/Safe Area 회피를 유지한다.
- 수동 드래그는 Chat/PlayerList 위에도 놓을 수 있다. 화면 밖·조작 불가능 위치·필수 Safe Area 경계만 clamp한다.
- 자동 placement와 별도 dragPlacement를 분리한다. 놓은 뒤의 주기적 갱신에서도 수동 선택을 유지한다.
- 기존 169개 테스트와 자동 배치 회귀를 유지하고 Chat 위·PlayerList 위·화면 경계·resize 접근성 검사를 추가한다.
- 다른 Party/Expedition 기능은 변경하지 않는다. 완료 후 Phase 0.8을 종료한다.
